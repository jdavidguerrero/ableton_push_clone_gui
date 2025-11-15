#ifndef SERIALCONTROLLER_H
#define SERIALCONTROLLER_H

#include <QObject>
#include <QSerialPort>
#include <QByteArray>
#include <QTimer>

class SerialController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(ConnectionState connectionState READ connectionState NOTIFY connectionStateChanged)
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

signals:
    void connectedChanged();
    void connectionStateChanged();
    void portNameChanged();
    void baudRateChanged();
    void connectionError(const QString &message);

private slots:
    void handleReadyRead();
    void handleError(QSerialPort::SerialPortError error);
    void handleReconnectTimeout();

private:
    void openPort();
    void closePort();
    void processFrame(quint8 cmd, const QByteArray &payload);
    void sendFrame(quint8 cmd, const QByteArray &payload = QByteArray());
    quint8 calculateChecksum(quint8 cmd, quint8 len, const QByteArray &payload) const;
    void setConnected(bool value);
    void setConnectionState(ConnectionState state);

    QSerialPort m_serial;
    QByteArray m_rxBuffer;
    bool m_connected = false;
    ConnectionState m_connectionState = Disconnected;
    QString m_portName = QStringLiteral("/dev/serial0");
    int m_baudRate = 115200;
    QTimer m_reconnectTimer;
};

#endif // SERIALCONTROLLER_H
