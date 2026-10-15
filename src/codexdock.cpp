#include "applet.h"
#include "pluginfactory.h"

#include <QDir>
#include <QDateTime>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStorageInfo>
#include <QStringList>
#include <QTimer>

#include <algorithm>

DS_USE_NAMESPACE

namespace {
QString readFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll());
}

QString speed(quint64 bytesPerSecond)
{
    const double kib = bytesPerSecond / 1024.0;
    if (kib >= 1024.0 * 1024.0)
        return QString::number(kib / (1024.0 * 1024.0), 'f', 1) + "G/s";
    if (kib >= 1024.0)
        return QString::number(kib / 1024.0, 'f', 1) + "M/s";
    return QString::number(kib, 'f', 1) + "K/s";
}
}

class CodexDockApplet : public DApplet
{
    Q_OBJECT
    Q_PROPERTY(int cpu READ cpu NOTIFY changed)
    Q_PROPERTY(int memory READ memory NOTIFY changed)
    Q_PROPERTY(int disk READ disk NOTIFY changed)
    Q_PROPERTY(QString down READ down NOTIFY changed)
    Q_PROPERTY(QString up READ up NOTIFY changed)
    Q_PROPERTY(int codexRemaining READ codexRemaining NOTIFY changed)
    Q_PROPERTY(int activeTasks READ activeTasks NOTIFY changed)
    Q_PROPERTY(QString interfaceName READ interfaceName NOTIFY changed)

public:
    explicit CodexDockApplet(QObject *parent = nullptr) : DApplet(parent)
    {
        connect(&m_statsTimer, &QTimer::timeout, this, &CodexDockApplet::updateStats);
        connect(&m_codexTimer, &QTimer::timeout, this, &CodexDockApplet::updateCodex);
        connect(&m_activityTimer, &QTimer::timeout, this, &CodexDockApplet::updateActivity);
        connect(&m_codexProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, &CodexDockApplet::codexFinished);
        connect(&m_activityProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, &CodexDockApplet::activityFinished);
        m_statsTimer.setInterval(1000);
        m_activityTimer.setInterval(3000);
        m_codexTimer.setInterval(60000);
    }

    bool init() override
    {
        if (!DApplet::init())
            return false;
        updateStats();
        updateCodex();
        updateActivity();
        m_statsTimer.start();
        m_activityTimer.start();
        m_codexTimer.start();
        return true;
    }

    int cpu() const { return m_cpu; }
    int memory() const { return m_memory; }
    int disk() const { return m_disk; }
    QString down() const { return m_down; }
    QString up() const { return m_up; }
    int codexRemaining() const { return m_codexRemaining; }
    int activeTasks() const { return m_activeTasks; }
    QString interfaceName() const { return m_interfaceName; }

signals:
    void changed();

private:
    void updateStats()
    {
        const QString cpuLine = readFile("/proc/stat").section('\n', 0, 0);
        const QStringList fields = cpuLine.simplified().split(' ');
        if (fields.size() >= 5 && fields.first() == "cpu") {
            quint64 total = 0;
            for (int i = 1; i < fields.size(); ++i)
                total += fields.at(i).toULongLong();
            const quint64 idle = fields.at(4).toULongLong() + (fields.size() > 5 ? fields.at(5).toULongLong() : 0);
            if (m_lastCpuTotal && total > m_lastCpuTotal)
                m_cpu = qBound(0, int(100 * (1.0 - double(idle - m_lastCpuIdle) / double(total - m_lastCpuTotal))), 100);
            m_lastCpuTotal = total;
            m_lastCpuIdle = idle;
        }

        quint64 memTotal = 0, memAvailable = 0;
        const QStringList memLines = readFile("/proc/meminfo").split('\n');
        for (const QString &line : memLines) {
            if (line.startsWith("MemTotal:")) memTotal = line.simplified().split(' ').value(1).toULongLong();
            if (line.startsWith("MemAvailable:")) memAvailable = line.simplified().split(' ').value(1).toULongLong();
        }
        if (memTotal)
            m_memory = qBound(0, int(100.0 * (memTotal - memAvailable) / memTotal), 100);

        const QStorageInfo root = QStorageInfo::root();
        if (root.isValid() && root.bytesTotal() > 0)
            m_disk = qBound(0, int(100.0 * (root.bytesTotal() - root.bytesAvailable()) / root.bytesTotal()), 100);

        if (m_interfaceName.isEmpty()) {
            const QStringList routes = readFile("/proc/net/route").split('\n');
            for (const QString &line : routes.mid(1)) {
                const QStringList parts = line.simplified().split(' ');
                if (parts.size() > 1 && parts.at(1) == "00000000") {
                    m_interfaceName = parts.first();
                    break;
                }
            }
        }
        const QStringList networkLines = readFile("/proc/net/dev").split('\n');
        for (const QString &line : networkLines) {
            if (!line.contains(':')) continue;
            const QString iface = line.section(':', 0, 0).trimmed();
            if (iface != m_interfaceName) continue;
            const QStringList parts = line.section(':', 1).simplified().split(' ');
            if (parts.size() < 9) break;
            const quint64 rx = parts.at(0).toULongLong();
            const quint64 tx = parts.at(8).toULongLong();
            if (m_lastNetworkTime.isValid()) {
                const qint64 elapsed = m_lastNetworkTime.msecsTo(QDateTime::currentDateTimeUtc());
                if (elapsed > 0) {
                    m_down = speed(rx >= m_lastRx ? (rx - m_lastRx) * 1000 / elapsed : 0);
                    m_up = speed(tx >= m_lastTx ? (tx - m_lastTx) * 1000 / elapsed : 0);
                }
            }
            m_lastRx = rx;
            m_lastTx = tx;
            m_lastNetworkTime = QDateTime::currentDateTimeUtc();
            break;
        }
        emit changed();
    }

    void updateCodex()
    {
        if (m_codexProcess.state() != QProcess::NotRunning)
            return;
        const QString helper = QDir::homePath() + "/.local/share/codex-dock-plugin/codex-rate-status.py";
        m_codexProcess.start("/usr/bin/python3", {helper});
        QTimer::singleShot(20000, this, [this]() {
            if (m_codexProcess.state() != QProcess::NotRunning)
                m_codexProcess.kill();
        });
    }

    void codexFinished(int exitCode, QProcess::ExitStatus status)
    {
        if (status != QProcess::NormalExit || exitCode != 0) {
            m_codexRemaining = -1;
            emit changed();
            return;
        }
        const QJsonObject data = QJsonDocument::fromJson(m_codexProcess.readAllStandardOutput()).object();
        m_codexRemaining = data.value("remaining").toInt(-1);
        emit changed();
    }

    void updateActivity()
    {
        if (m_activityProcess.state() != QProcess::NotRunning)
            return;
        const QString helper = QDir::homePath() + "/.local/share/codex-dock-plugin/codex-activity.py";
        m_activityProcess.start("/usr/bin/python3", {helper});
        QTimer::singleShot(2500, this, [this]() {
            if (m_activityProcess.state() != QProcess::NotRunning)
                m_activityProcess.kill();
        });
    }

    void activityFinished(int exitCode, QProcess::ExitStatus status)
    {
        if (status != QProcess::NormalExit || exitCode != 0) {
            m_activeTasks = -1;
        } else {
            const QJsonObject data = QJsonDocument::fromJson(m_activityProcess.readAllStandardOutput()).object();
            m_activeTasks = data.value("active").toInt(-1);
        }
        emit changed();
    }

    QTimer m_statsTimer;
    QTimer m_codexTimer;
    QTimer m_activityTimer;
    QProcess m_codexProcess;
    QProcess m_activityProcess;
    int m_cpu = 0, m_memory = 0, m_disk = 0, m_codexRemaining = -1, m_activeTasks = -1;
    quint64 m_lastCpuTotal = 0, m_lastCpuIdle = 0, m_lastRx = 0, m_lastTx = 0;
    QDateTime m_lastNetworkTime;
    QString m_down = "0 KiB/s", m_up = "0 KiB/s";
    QString m_interfaceName;
};

D_APPLET_CLASS(CodexDockApplet)
#include "codexdock.moc"
