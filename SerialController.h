#ifndef SERIALCONTROLLER_H
#define SERIALCONTROLLER_H

#include <QObject>
#include <QSerialPort>
#include <QByteArray>
#include <QTimer>
#include <QBitArray>

#include "ClipGridModel.h"
#include "TrackListModel.h"
#include "SceneListModel.h"

class SerialController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(ConnectionState connectionState READ connectionState NOTIFY connectionStateChanged)
    Q_PROPERTY(ClipGridModel* clipModel READ clipModel CONSTANT)
    Q_PROPERTY(TrackListModel* trackModel READ trackModel CONSTANT)
    Q_PROPERTY(SceneListModel* sceneModel READ sceneModel CONSTANT)
    Q_PROPERTY(bool transportPlaying READ transportPlaying NOTIFY transportStateChanged)
    Q_PROPERTY(bool transportRecording READ transportRecording NOTIFY transportStateChanged)
    Q_PROPERTY(bool transportLoop READ transportLoop NOTIFY transportStateChanged)
    Q_PROPERTY(double transportTempo READ transportTempo NOTIFY transportTempoChanged)
    Q_PROPERTY(QString transportPosition READ transportPosition NOTIFY transportPositionChanged)
    Q_PROPERTY(QString portName READ portName WRITE setPortName NOTIFY portNameChanged)
    Q_PROPERTY(int baudRate READ baudRate WRITE setBaudRate NOTIFY baudRateChanged)

public:
    enum ConnectionState {
        Disconnected,
        WaitingHandshake,
        Connected
    };
    Q_ENUM(ConnectionState)

    explicit SerialController(QObject *parent = nullptr);

    bool isConnected() const { return m_connected; }
    ConnectionState connectionState() const { return m_connectionState; }
    QString portName() const { return m_portName; }
    void setPortName(const QString &name);

    int baudRate() const { return m_baudRate; }
    void setBaudRate(int baud);

    Q_INVOKABLE void reconnect();
    Q_INVOKABLE void requestDisconnect();
    Q_INVOKABLE void sendTransportPlay(bool state);
    Q_INVOKABLE void sendTransportRecord(bool state);
    Q_INVOKABLE void sendTransportLoop(bool state);
    Q_INVOKABLE void sendClipTrigger(int track, int scene);

    ClipGridModel* clipModel() const { return m_clipModel; }
    TrackListModel* trackModel() const { return m_trackModel; }
    SceneListModel* sceneModel() const { return m_sceneModel; }

    bool transportPlaying() const { return m_transportPlaying; }
    bool transportRecording() const { return m_transportRecording; }
    bool transportLoop() const { return m_transportLoop; }
    double transportTempo() const { return m_transportTempo; }
    QString transportPosition() const { return m_transportPosition; }

signals:
    void connectedChanged();
    void connectionStateChanged();
    void portNameChanged();
    void baudRateChanged();
    void connectionError(const QString &message);
    void transportStateChanged();
    void transportTempoChanged();
    void transportPositionChanged();

private slots:
    void handleReadyRead();
    void handleError(QSerialPort::SerialPortError error);
    void handleReconnectTimeout();
    void handleTrackBatchTimeout();

private:
    void openPort();
    void closePort();
    void processFrame(quint8 cmd, const QByteArray &payload);
    void sendFrame(quint8 cmd, const QByteArray &payload = QByteArray());
    quint8 calculateChecksum(quint8 cmd, quint8 len, const QByteArray &payload) const;
    void setConnected(bool value);
    void setConnectionState(ConnectionState state);
    void handleClipName(const QByteArray &payload);
    void handleGridUpdate7bit(const QByteArray &payload);
    void handleGridUpdate14bit(const QByteArray &payload);
    void handlePadUpdate14bit(const QByteArray &payload);
    void handlePadUpdate7bit(const QByteArray &payload);
    void handleClipState(const QByteArray &payload);
    void updatePadColor(int track, int scene, const QColor &color);
    void handleTrackName(const QByteArray &payload);
    void handleTrackColor(const QByteArray &payload);
    void handleSceneName(const QByteArray &payload);
    void handleSceneColor(const QByteArray &payload);
    void handleSceneTriggered(const QByteArray &payload);
    void handleTransportCommand(quint8 cmd, const QByteArray &payload);
    void scheduleTrackCleanup(int trackIndex);

    QSerialPort m_serial;
    QByteArray m_rxBuffer;
    bool m_connected = false;
    ConnectionState m_connectionState = Disconnected;
    QString m_portName = QStringLiteral("/dev/serial0");
    int m_baudRate = 115200;
    QTimer m_reconnectTimer;
    QTimer m_trackCleanupTimer;
    ClipGridModel *m_clipModel = nullptr;
    TrackListModel *m_trackModel = nullptr;
    SceneListModel *m_sceneModel = nullptr;
    bool m_transportPlaying = false;
    bool m_transportRecording = false;
    bool m_transportLoop = false;
    double m_transportTempo = 120.0;
    QString m_transportPosition = QStringLiteral("1.1.1");
    QBitArray m_trackPresence;
    bool m_trackBatchSawZero = false;
};

#endif // SERIALCONTROLLER_H
