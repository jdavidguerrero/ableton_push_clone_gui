#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "SerialController.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    auto serialController = new SerialController(&app);
    engine.rootContext()->setContextProperty(QStringLiteral("serialController"), serialController);

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    // Qt6: Use objectCreationFailed signal
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
#else
    // Qt5: Add import path for PushClone module
    engine.addImportPath(QStringLiteral("qrc:/qt/qml"));
#endif

    // Load Main.qml directly from resources
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/PushClone/Main.qml")));

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    // Qt5: Check if root objects is empty
    if (engine.rootObjects().isEmpty())
        return -1;
#endif

    return app.exec();
}
