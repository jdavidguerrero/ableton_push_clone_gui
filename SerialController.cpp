#include "SerialController.h"

#include <QCoreApplication>
#include <QDebug>
#include <QColor>
#include <QtMath>

namespace {
constexpr quint8 FrameHeader = 0xAA;
constexpr quint8 CmdHandshake = 0x00;
constexpr quint8 CmdHandshakeReply = 0x01;
constexpr quint8 CmdClipState = 0x10;
constexpr quint8 CmdClipName = 0x14;
constexpr quint8 CmdSceneState = 0x1A;
constexpr quint8 CmdSceneName = 0x1B;
constexpr quint8 CmdSceneColor = 0x1C;
constexpr quint8 CmdSceneTriggered = 0x1D;
constexpr quint8 CmdGridUpdate7bit = 0x60;
constexpr quint8 CmdLedRgbState = 0x84;
constexpr quint8 CmdPing = 0x03;
constexpr quint8 CmdDisconnect = 0x02;
constexpr quint8 CmdLedGridUpdate14 = 0xA6;
constexpr quint8 CmdLedPadUpdate14 = 0xA7;
constexpr quint8 CmdTrackName = 0x27;
constexpr quint8 CmdTrackColor = 0x28;
constexpr quint8 CmdTransportPlay = 0x40;
constexpr quint8 CmdTransportRecord = 0x41;
constexpr quint8 CmdTransportLoop = 0x42;
constexpr quint8 CmdTransportTempo = 0x43;
constexpr quint8 CmdTransportPosition = 0x45;
constexpr quint8 CmdTransportState = 0x49;

int decode14Bit(quint8 msb, quint8 lsb)
{
    return ((msb & 0x7F) << 7) | (lsb & 0x7F);
}

int normalize14To8(quint8 msb, quint8 lsb)
{
    // Colors are packed as two 7-bit MIDI-safe bytes that together represent
    // the original 0-255 component. Just reconstruct and clamp.
    return qBound(0, decode14Bit(msb, lsb), 255);
}

int normalize7To8(quint8 value)
{
    return static_cast<int>(((value & 0x7F) * 255) / 127);
}

QColor colorFrom14(const quint8 *data)
{
    return QColor(normalize14To8(data[0], data[1]),
                  normalize14To8(data[2], data[3]),
                  normalize14To8(data[4], data[5]));
}

QColor colorFrom7(const quint8 *data)
{
    return QColor(normalize7To8(data[0]),
                  normalize7To8(data[1]),
                  normalize7To8(data[2]));
}

QString readLengthPrefixedString(const QByteArray &payload, int offset)
{
    if (offset >= payload.size())
        return QString();

    const int remaining = payload.size() - offset;
    if (remaining <= 0)
        return QString();

    const quint8 declaredLen = static_cast<quint8>(payload.at(offset));
    const int available = remaining - 1;
    if (declaredLen > 0 && available >= declaredLen)
        return QString::fromUtf8(payload.constData() + offset + 1, declaredLen);

    if (available <= 0)
        return QString();

    // Fallback: treat the rest as a raw UTF-8 string (legacy packets)
    return QString::fromUtf8(payload.constData() + offset, remaining);
}
}

SerialController::SerialController(QObject *parent)
    : QObject(parent)
    , m_clipModel(new ClipGridModel(this))
    , m_trackModel(new TrackListModel(this))
    , m_sceneModel(new SceneListModel(this))
{
    connect(&m_serial, &QSerialPort::readyRead, this, &SerialController::handleReadyRead);
    connect(&m_serial, &QSerialPort::errorOccurred, this, &SerialController::handleError);

    m_reconnectTimer.setSingleShot(true);
    m_reconnectTimer.setInterval(2000);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &SerialController::handleReconnectTimeout);

    m_trackCleanupTimer.setSingleShot(true);
    m_trackCleanupTimer.setInterval(100);
    connect(&m_trackCleanupTimer, &QTimer::timeout, this, &SerialController::handleTrackBatchTimeout);

    m_trackPresence.resize(8);
    m_trackPresence.fill(false);

    openPort();
}

void SerialController::setPortName(const QString &name)
{
    if (m_portName == name)
        return;

    m_portName = name;
    emit portNameChanged();
    reconnect();
}

void SerialController::setBaudRate(int baud)
{
    if (m_baudRate == baud)
        return;

    m_baudRate = baud;
    emit baudRateChanged();
    reconnect();
}

void SerialController::reconnect()
{
    closePort();
    openPort();
}

void SerialController::requestDisconnect()
{
    if (m_serial.isOpen()) {
        qInfo() << "Solicitando desconexión (CMD_DISCONNECT)";
        sendFrame(CmdDisconnect);
    }
    setConnected(false);
    setConnectionState(WaitingHandshake);
}

void SerialController::sendTransportPlay(bool state)
{
    QByteArray payload(1, char(state ? 1 : 0));
    sendFrame(CmdTransportPlay, payload);
}

void SerialController::sendTransportRecord(bool state)
{
    QByteArray payload(1, char(state ? 1 : 0));
    sendFrame(CmdTransportRecord, payload);
}

void SerialController::sendTransportLoop(bool state)
{
    QByteArray payload(1, char(state ? 1 : 0));
    sendFrame(CmdTransportLoop, payload);
}

void SerialController::openPort()
{
    if (m_serial.isOpen())
        return;

    m_serial.setPortName(m_portName);
    m_serial.setBaudRate(m_baudRate);
    m_serial.setDataBits(QSerialPort::Data8);
    m_serial.setParity(QSerialPort::NoParity);
    m_serial.setStopBits(QSerialPort::OneStop);
    m_serial.setFlowControl(QSerialPort::NoFlowControl);

    if (!m_serial.open(QIODevice::ReadWrite)) {
        const QString message = tr("Unable to open %1: %2").arg(m_portName, m_serial.errorString());
        qWarning() << message;
        emit connectionError(message);
        if (!m_reconnectTimer.isActive())
            m_reconnectTimer.start();
        return;
    }

    qInfo() << "Serial port opened on" << m_portName << "@" << m_baudRate;
    setConnectionState(WaitingHandshake);
}

void SerialController::closePort()
{
    if (!m_serial.isOpen())
        return;

    m_serial.close();
    setConnected(false);
    setConnectionState(Disconnected);
    m_rxBuffer.clear();
    m_trackCleanupTimer.stop();
    m_trackBatchSawZero = false;
    m_trackPresence.fill(false);
    if (m_trackModel)
        m_trackModel->resetAll();
}

void SerialController::handleReadyRead()
{
    const QByteArray chunk = m_serial.readAll();
    if (!chunk.isEmpty()) {
        qInfo().noquote() << QStringLiteral("[RX] RAW %1")
                             .arg(QString::fromLatin1(chunk.toHex(' ')));
    }
    m_rxBuffer.append(chunk);

    while (true) {
        const int syncIndex = m_rxBuffer.indexOf(char(FrameHeader));
        if (syncIndex < 0) {
            // No byte de sincronización en el buffer -> descartar ruido
            if (!m_rxBuffer.isEmpty())
                qWarning() << "Descartando" << m_rxBuffer.size() << "bytes sin SYNC";
            m_rxBuffer.clear();
            break;
        }

        if (syncIndex > 0) {
            // Quitar bytes previos hasta el siguiente SYNC
            m_rxBuffer.remove(0, syncIndex);
        }

        if (m_rxBuffer.size() < 3)
            break;

        const quint8 cmd = quint8(m_rxBuffer.at(1));
        const quint8 len = quint8(m_rxBuffer.at(2));

        const int totalSize = 3 + len + 1;
        if (m_rxBuffer.size() < totalSize)
            return; // wait for more data

        const QByteArray payload = m_rxBuffer.mid(3, len);
        const quint8 checksum = quint8(m_rxBuffer.at(3 + len));
        if (checksum != calculateChecksum(cmd, len, payload)) {
            qWarning() << "Checksum mismatch for cmd" << Qt::hex << cmd
                       << "len" << len
                       << "payload" << payload.toHex(' ');
            // Reiniciar parser desde el próximo SYNC
            m_rxBuffer.remove(0, 1);
            continue;
        }

        qInfo().noquote() << QStringLiteral("[RX] FRAME cmd=0x%1 len=%2 payload=%3")
                             .arg(cmd, 2, 16, QLatin1Char('0'))
                             .arg(len)
                             .arg(QString::fromLatin1(payload.toHex(' ')));
        processFrame(cmd, payload);
        m_rxBuffer.remove(0, totalSize);
        // Reset parser state before continuar
        continue;
    }
}

void SerialController::handleError(QSerialPort::SerialPortError error)
{
    if (error == QSerialPort::NoError)
        return;

    const QString message = tr("Serial error (%1): %2").arg(int(error)).arg(m_serial.errorString());
    qWarning() << message;
    emit connectionError(message);
    closePort();

    if (!m_reconnectTimer.isActive())
        m_reconnectTimer.start();
}

void SerialController::handleReconnectTimeout()
{
    if (!m_serial.isOpen())
        openPort();
}

void SerialController::processFrame(quint8 cmd, const QByteArray &payload)
{
    switch (cmd) {
    case CmdHandshake:
        if (payload == QByteArrayLiteral("PUSHCLONE_GUI")) {
            qInfo() << "Handshake recibido";
            setConnected(true);
            setConnectionState(Connected);
            sendFrame(CmdHandshakeReply, QByteArrayLiteral("PUSHCLONE_GUI"));
        } else {
            qWarning() << "Handshake payload inesperado" << payload;
        }
        break;
    case CmdPing:
        sendFrame(CmdPing);
        break;
    case CmdDisconnect:
        qInfo() << "CMD_DISCONNECT recibido";
        setConnected(false);
        setConnectionState(WaitingHandshake);
        break;
    case CmdClipName:
        handleClipName(payload);
        break;
    case CmdGridUpdate7bit:
        handleGridUpdate7bit(payload);
        break;
    case CmdLedGridUpdate14:
        handleGridUpdate14bit(payload);
        break;
    case CmdLedPadUpdate14:
        handlePadUpdate14bit(payload);
        break;
    case CmdLedRgbState:
        handlePadUpdate7bit(payload);
        break;
    case CmdClipState:
        handleClipState(payload);
        break;
    case CmdTrackName:
        handleTrackName(payload);
        break;
    case CmdTrackColor:
        handleTrackColor(payload);
        break;
    case CmdSceneName:
        handleSceneName(payload);
        break;
    case CmdSceneColor:
        handleSceneColor(payload);
        break;
    case CmdSceneTriggered:
    case CmdSceneState:
        handleSceneTriggered(payload);
        break;
    case CmdTransportPlay:
    case CmdTransportRecord:
    case CmdTransportLoop:
    case CmdTransportTempo:
    case CmdTransportPosition:
    case CmdTransportState:
        handleTransportCommand(cmd, payload);
        break;
    default:
        // Por ahora solo registramos otros comandos para depuración.
        qDebug() << "Frame recibido:" << Qt::hex << cmd << "len" << payload.size();
        break;
    }
}

void SerialController::sendFrame(quint8 cmd, const QByteArray &payload)
{
    if (!m_serial.isOpen()) {
        qWarning() << "No serial port open to send frame";
        return;
    }

    const quint8 len = static_cast<quint8>(payload.size());
    QByteArray frame;
    frame.reserve(3 + payload.size() + 1);
    frame.append(char(FrameHeader));
    frame.append(char(cmd));
    frame.append(char(len));
    frame.append(payload);
    frame.append(char(calculateChecksum(cmd, len, payload)));

    qInfo().noquote() << QStringLiteral("[TX] FRAME cmd=0x%1 len=%2 payload=%3")
                         .arg(cmd, 2, 16, QLatin1Char('0'))
                         .arg(len)
                         .arg(QString::fromLatin1(payload.toHex(' ')));

    const qint64 written = m_serial.write(frame);
    if (written != frame.size()) {
        qWarning() << "Failed to write complete frame";
    }
    m_serial.flush();

    // Opcional: volcar los bytes exactos que salieron (incluyendo header y checksum)
    qInfo().noquote() << QStringLiteral("[TX] RAW %1")
                         .arg(QString::fromLatin1(frame.toHex(' ')));
}

quint8 SerialController::calculateChecksum(quint8 cmd, quint8 len, const QByteArray &payload) const
{
    quint8 checksum = cmd ^ len;
    for (const char byte : payload)
        checksum ^= quint8(byte);
    return checksum;
}

void SerialController::setConnected(bool value)
{
    if (m_connected == value)
        return;

    m_connected = value;
    emit connectedChanged();
}

void SerialController::setConnectionState(ConnectionState state)
{
    if (m_connectionState == state)
        return;
    m_connectionState = state;
    emit connectionStateChanged();

}

void SerialController::handleClipName(const QByteArray &payload)
{
    if (payload.size() < 2 || !m_clipModel)
        return;
    const int track = static_cast<quint8>(payload.at(0));
    const int scene = static_cast<quint8>(payload.at(1));
    const QString name = readLengthPrefixedString(payload, 2);
    m_clipModel->setClipName(track, scene, name);
}

void SerialController::handleGridUpdate7bit(const QByteArray &payload)
{
    if (!m_clipModel || payload.size() < 3)
        return;
    const int padCount = payload.size() / 3;
    const int totalRows = m_clipModel->rowCount();
    for (int i = 0; i < padCount && i < totalRows; ++i) {
        const quint8 *colorData = reinterpret_cast<const quint8 *>(payload.constData() + i * 3);
        updatePadColor(i % 8, i / 8, colorFrom7(colorData));
    }
}

void SerialController::handleGridUpdate14bit(const QByteArray &payload)
{
    if (!m_clipModel || payload.size() < 6)
        return;
    const int padCount = payload.size() / 6;
    const int totalRows = m_clipModel->rowCount();
    for (int i = 0; i < padCount && i < totalRows; ++i) {
        const quint8 *colorData = reinterpret_cast<const quint8 *>(payload.constData() + i * 6);
        updatePadColor(i % 8, i / 8, colorFrom14(colorData));
    }
}

void SerialController::handlePadUpdate14bit(const QByteArray &payload)
{
    if (!m_clipModel || payload.size() < 7)
        return;

    int track = -1;
    int scene = -1;
    int offset = 1;

    if (payload.size() >= 8 &&
        static_cast<quint8>(payload.at(0)) < 8 &&
        static_cast<quint8>(payload.at(1)) < 4) {
        track = static_cast<quint8>(payload.at(0));
        scene = static_cast<quint8>(payload.at(1));
        offset = 2;
    } else {
        const int padIndex = static_cast<quint8>(payload.at(0));
        track = padIndex % 8;
        scene = padIndex / 8;
    }

    if (payload.size() < offset + 6)
        return;

    const quint8 *colorData = reinterpret_cast<const quint8 *>(payload.constData() + offset);
    updatePadColor(track, scene, colorFrom14(colorData));
}

void SerialController::handlePadUpdate7bit(const QByteArray &payload)
{
    if (!m_clipModel || payload.size() < 5)
        return;

    const int track = static_cast<quint8>(payload.at(0));
    const int scene = static_cast<quint8>(payload.at(1));
    const quint8 *colorData = reinterpret_cast<const quint8 *>(payload.constData() + 2);
    updatePadColor(track, scene, colorFrom7(colorData));
}

void SerialController::handleClipState(const QByteArray &payload)
{
    if (!m_clipModel || payload.size() < 3)
        return;
    const int track = static_cast<quint8>(payload.at(0));
    const int scene = static_cast<quint8>(payload.at(1));
    const int state = static_cast<quint8>(payload.at(2));
    m_clipModel->setClipState(track, scene, state);

    if (payload.size() >= 9) {
        const quint8 *colorData = reinterpret_cast<const quint8 *>(payload.constData() + 3);
        updatePadColor(track, scene, colorFrom14(colorData));
    }
}

void SerialController::updatePadColor(int track, int scene, const QColor &color)
{
    if (!m_clipModel)
        return;
    m_clipModel->setClipColor(track, scene, color);
}

void SerialController::handleTrackName(const QByteArray &payload)
{
    if (!m_trackModel || payload.size() < 1)
        return;
    const int track = static_cast<quint8>(payload.at(0));
    const QString name = readLengthPrefixedString(payload, 1);
    m_trackModel->setTrackName(track, name);
    scheduleTrackCleanup(track);
}

void SerialController::handleTrackColor(const QByteArray &payload)
{
    if (!m_trackModel || payload.size() < 4)
        return;
    const int track = static_cast<quint8>(payload.at(0));
    const quint8 *colorData = reinterpret_cast<const quint8 *>(payload.constData() + 1);
    QColor color = (payload.size() >= 7) ? colorFrom14(colorData)
                                         : colorFrom7(colorData);
    m_trackModel->setTrackColor(track, color);
}

void SerialController::handleSceneName(const QByteArray &payload)
{
    if (!m_sceneModel || payload.size() < 1)
        return;
    const int scene = static_cast<quint8>(payload.at(0));
    const QString name = QString::fromUtf8(payload.constData() + 1, payload.size() - 1);
    m_sceneModel->setSceneName(scene, name);
}

void SerialController::handleSceneColor(const QByteArray &payload)
{
    if (!m_sceneModel || payload.size() < 4)
        return;
    const int scene = static_cast<quint8>(payload.at(0));
    const quint8 *colorData = reinterpret_cast<const quint8 *>(payload.constData() + 1);
    QColor color = (payload.size() >= 7) ? colorFrom14(colorData)
                                         : colorFrom7(colorData);
    m_sceneModel->setSceneColor(scene, color);
}

void SerialController::handleSceneTriggered(const QByteArray &payload)
{
    if (!m_sceneModel || payload.size() < 2)
        return;
    const int scene = static_cast<quint8>(payload.at(0));
    const bool triggered = static_cast<quint8>(payload.at(1)) != 0;
    m_sceneModel->setSceneTriggered(scene, triggered);
}

void SerialController::handleTransportCommand(quint8 cmd, const QByteArray &payload)
{
    auto boolValue = [&](const QByteArray &data) -> bool {
        if (data.isEmpty())
            return false;
        return static_cast<quint8>(data.at(0)) != 0;
    };

    switch (cmd) {
    case CmdTransportPlay:
        if (m_transportPlaying != boolValue(payload)) {
            m_transportPlaying = boolValue(payload);
            emit transportStateChanged();
        }
        break;
    case CmdTransportRecord:
        if (m_transportRecording != boolValue(payload)) {
            m_transportRecording = boolValue(payload);
            emit transportStateChanged();
        }
        break;
    case CmdTransportLoop:
        if (m_transportLoop != boolValue(payload)) {
            m_transportLoop = boolValue(payload);
            emit transportStateChanged();
        }
        break;
    case CmdTransportTempo:
        if (payload.size() >= 2) {
            const int value = (static_cast<quint8>(payload.at(0)) << 8) |
                              static_cast<quint8>(payload.at(1));
            const double tempo = value / 10.0;
            if (!qFuzzyCompare(tempo, m_transportTempo)) {
                m_transportTempo = tempo;
                emit transportTempoChanged();
            }
        }
        break;
    case CmdTransportPosition:
        if (!payload.isEmpty()) {
            const QString position = QString::fromUtf8(payload);
            if (m_transportPosition != position) {
                m_transportPosition = position;
                emit transportPositionChanged();
            }
        }
        break;
    case CmdTransportState:
        if (payload.size() >= 1) {
            const quint8 flags = static_cast<quint8>(payload.at(0));
            bool playing = flags & 0x01;
            bool recording = flags & 0x02;
            bool loop = flags & 0x04;
            bool changed = false;
            if (m_transportPlaying != playing) {
                m_transportPlaying = playing;
                changed = true;
            }
            if (m_transportRecording != recording) {
                m_transportRecording = recording;
                changed = true;
            }
            if (m_transportLoop != loop) {
                m_transportLoop = loop;
                changed = true;
            }
            if (changed)
                emit transportStateChanged();
        }
        break;
    default:
        break;
    }
}

void SerialController::scheduleTrackCleanup(int trackIndex)
{
    if (trackIndex >= 0 && trackIndex < m_trackPresence.size())
        m_trackPresence.setBit(trackIndex, true);

    if (trackIndex == 0)
        m_trackBatchSawZero = true;

    m_trackCleanupTimer.start();
}

void SerialController::handleTrackBatchTimeout()
{
    if (!m_trackModel)
        return;

    if (m_trackBatchSawZero) {
        int lastContiguous = -1;
        for (int i = 0; i < m_trackPresence.size(); ++i) {
            if (!m_trackPresence.testBit(i))
                break;
            lastContiguous = i;
        }
        m_trackModel->clearAbove(lastContiguous);
    }

    m_trackPresence.fill(false);
    m_trackBatchSawZero = false;
}
