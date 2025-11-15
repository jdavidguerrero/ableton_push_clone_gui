#include "SerialController.h"

#include <QCoreApplication>
#include <QDebug>

namespace {
constexpr quint8 FrameHeader = 0xAA;
constexpr quint8 CmdHandshake = 0x00;
constexpr quint8 CmdHandshakeReply = 0x01;
constexpr quint8 CmdPing = 0x03;
constexpr quint8 CmdDisconnect = 0x02;
}

SerialController::SerialController(QObject *parent)
    : QObject(parent)
{
    connect(&m_serial, &QSerialPort::readyRead, this, &SerialController::handleReadyRead);
    connect(&m_serial, &QSerialPort::errorOccurred, this, &SerialController::handleError);

    m_reconnectTimer.setSingleShot(true);
    m_reconnectTimer.setInterval(2000);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &SerialController::handleReconnectTimeout);

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
            sendFrame(CmdHandshakeReply);
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
