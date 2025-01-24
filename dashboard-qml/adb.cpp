/*
 * WiVRn VR streaming
 * Copyright (C) 2024  Guillaume Meunier <guillaume.meunier@centraliens.net>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include "adb.h"

#include "utils/flatpak.h"
#include <QProcess>
#include <QRegularExpression>
#include <algorithm>
#include <ranges>
#include <vector>

using namespace std::chrono_literals;

template <typename... Args>
std::unique_ptr<QProcess> escape_sandbox(const std::string & executable, Args &&... args_orig)
{
	auto process = std::make_unique<QProcess>();
	QStringList args;

	if (wivrn::flatpak_key(wivrn::flatpak::section::session_bus_policy, "org.freedesktop.Flatpak") == "talk")
	{
		process->setProgram("flatpak-spawn");
		args.push_back("--host");
		args.push_back(QString::fromStdString(executable));
	}
	else
	{
		process->setProgram(QString::fromStdString(executable));
	}

	auto to_QString = [](const auto & s) {
		using T = std::decay_t<std::remove_cv_t<std::remove_reference_t<decltype(s)>>>;

		if constexpr (std::is_same_v<T, QString>)
			return s;
		if constexpr (std::is_same_v<T, char *>)
			return s;
		if constexpr (std::is_same_v<T, std::string>)
			return QString::fromStdString(s);
	};

	(args.push_back(to_QString(args_orig)), ...);

	process->setArguments(args);

	return process;
}

adb::adb()
{
	m_poll_devices_timer.setInterval(500ms);
	connect(&m_poll_devices_timer, &QTimer::timeout, this, &adb::on_poll_devices_timeout);

	checkIfAdbIsInstalled();
}

// BEGIN Check if ADB is installed
void adb::checkIfAdbIsInstalled()
{
	if (m_check_adb_installed)
		return;

	m_check_adb_installed = escape_sandbox("which", "adb");

	connect(m_check_adb_installed.get(), &QProcess::finished, this, &adb::on_check_adb_installed_finished);
	m_check_adb_installed->start();
}

void adb::on_check_adb_installed_finished(int exit_code, QProcess::ExitStatus exit_status)
{
	if (exit_status == QProcess::NormalExit and exit_code == 0)
	{
		if (!m_adb_installed)
		{
			adbInstalledChanged(m_adb_installed = true);
			m_poll_devices_timer.start();
			on_poll_devices_timeout();
		}
	}
	else
	{
		if (m_adb_installed)
		{
			adbInstalledChanged(m_adb_installed = false);
			m_poll_devices_timer.stop();
		}
	}

	m_check_adb_installed.release()->deleteLater();
}
// END

// BEGIN Poll devices
void adb::on_poll_devices_timeout()
{
	if (m_poll_devices_process)
		return;

	m_poll_devices_process = escape_sandbox("adb", "devices");
	connect(m_poll_devices_process.get(), &QProcess::finished, this, &adb::on_poll_devices_process_finished);
	m_poll_devices_process->start();
}

void adb::on_poll_devices_process_finished(int exit_code, QProcess::ExitStatus exit_status)
{
	if (exit_status == QProcess::NormalExit and exit_code == 0)
	{
		auto out = m_poll_devices_process->readAllStandardOutput();
		auto lines = QString{out}.split('\n');

		// Remove "List of devices attached"
		if (not lines.empty())
			lines.pop_front();

		std::vector<adb::device> devs;
		for (auto & line: lines)
		{
			auto words = line.split('\t', Qt::SkipEmptyParts);
			device dev;

			if (words.empty())
				continue;
			dev.serial = words.front();
			words.pop_front();

			if (words.empty())
				continue;
			dev.state = words.front();

			devs.push_back(dev);
		}

		for (size_t i = 0; i < m_android_devices.size();)
		{
			auto it = std::ranges::find(devs, m_android_devices[i].serial, &device::serial);
			if (it == devs.end())
			{
				beginRemoveRows({}, i, i);
				m_android_devices.erase(m_android_devices.begin() + i);
				endRemoveRows();
			}
			else
			{
				if (m_android_devices[i].state != it->state)
				{
					m_android_devices[i].state = it->state;
					dataChanged(index(i), index(i), {RoleState});
				}

				++i;
			}
		}

		for (device & dev: devs)
		{
			if (not std::ranges::contains(m_android_devices, dev.serial, &device::serial))
			{
				add_device(std::move(dev));
			}
		}
	}

	m_poll_devices_process.release()->deleteLater();
}
// END

// BEGIN Add device
void adb::add_device(device && new_dev)
{
	auto process = escape_sandbox("adb", "-s", new_dev.serial, "shell", "pm", "list", "packages").release();
	connect(process, &QProcess::finished, this, [process, dev = std::move(new_dev), this](int exit_code, QProcess::ExitStatus exit_status) mutable { add_device_on_package_list(exit_code, exit_status, process, std::move(dev)); });
	process->start();
}

void adb::add_device_on_package_list(int exit_code, QProcess::ExitStatus exit_status, QProcess * process, device && dev)
{
	if (exit_status == QProcess::NormalExit and exit_code == 0)
	{
		auto out = process->readAllStandardOutput();

		for (auto & line: QString{out}.split('\n'))
		{
			if (line == "package:org.meumeu.wivrn" or line.startsWith("package:org.meumeu.wivrn."))
			{
				dev.is_wivrn_installed = true;
				dev.app = line.mid(8);
				break;
			}
		}

		process->deleteLater();

		process = escape_sandbox("adb", "-s", dev.serial, "shell", "getprop").release();
		connect(process, &QProcess::finished, this, [process, dev = std::move(dev), this](int exit_code, QProcess::ExitStatus exit_status) mutable { add_device_on_getprop(exit_code, exit_status, process, std::move(dev)); });
		process->start();
	}
	else
	{
		process->deleteLater();
	}
}

void adb::add_device_on_getprop(int exit_code, QProcess::ExitStatus exit_status, QProcess * process, device && dev)
{
	if (exit_status == QProcess::NormalExit and exit_code == 0)
	{
		auto out = process->readAllStandardOutput();
		static const QRegularExpression re{R"(\[(?<name>.*)\]: \[(?<value>.*)\])"};

		for (auto & line: QString{out}.split('\n'))
		{
			if (auto match = re.match(line); match.hasMatch())
			{
				dev.properties.insert({match.captured("name"), match.captured("value")});
			}
		}

		auto it = std::ranges::find(m_android_devices, dev.serial, &device::serial);
		if (it == m_android_devices.end())
		{
			auto idx = m_android_devices.size();
			beginInsertRows({}, idx, idx);
			m_android_devices.push_back(dev);
			endInsertRows();
		}
		else
		{
			*it = std::move(dev);
			auto idx = index(m_android_devices.begin() - it);
			dataChanged(idx, idx);
		}
	}

	process->deleteLater();
}
// END

// BEGIN Model implementation
QHash<int, QByteArray> adb::roleNames() const
{
	return QHash<int, QByteArray>{
	        {RoleSerial, "serial"},
	        {RoleIsWivrnInstalled, "isWivrnInstalled"},
	        {RoleManufacturer, "manufacturer"},
	        {RoleModel, "model"},
	        {RoleState, "state"},
	        {RoleProduct, "product"},
	        {RoleDevice, "device"},
	};
}

QVariant adb::data(const QModelIndex & index, int role) const
{
	switch (role)
	{
		case RoleSerial:
			return m_android_devices.at(index.row()).serial;

		case RoleState:
			return m_android_devices.at(index.row()).state;

		case RoleProduct: {
			auto it = m_android_devices.at(index.row()).properties.find("ro.product.name");
			if (it == m_android_devices.at(index.row()).properties.end())
				return "";
			else
				return it->second;
		}

		case RoleManufacturer: {
			auto it = m_android_devices.at(index.row()).properties.find("ro.product.manufacturer");
			if (it == m_android_devices.at(index.row()).properties.end())
				return "";
			else
				return it->second;
		}

		case RoleModel: {
			auto it = m_android_devices.at(index.row()).properties.find("ro.product.model");
			if (it == m_android_devices.at(index.row()).properties.end())
				return "";
			else
				return it->second;
		}

		case RoleDevice: {
			auto it = m_android_devices.at(index.row()).properties.find("ro.product.device");
			if (it == m_android_devices.at(index.row()).properties.end())
				return "";
			else
				return it->second;
		}

		case RoleIsWivrnInstalled:
			return m_android_devices.at(index.row()).is_wivrn_installed;

		default:
			return {};
	}
}
// END

// bool adb::installWivrnApk(QString serial, QString apkPath)
// {
// }

void adb::startUsbConnection(QString serial, QString pin)
{
	auto it = std::ranges::find(m_android_devices, serial, &device::serial);

	if (it == m_android_devices.end())
		return;

	auto process = escape_sandbox("adb", "-s", serial, "reverse", "tcp:9757", "tcp:9757").release();
	connect(process, &QProcess::finished, this, [=](int exit_code, QProcess::ExitStatus exit_status) mutable {
		process->deleteLater();

		// action: "android.intent.action.VIEW" or "android.intent.action.MAIN"
		QString uri = pin == "" ? "wivrn+tcp://127.0.0.1:9757" : "wivrn+tcp://:" + pin + "@127.0.0.1:9757";
		process = escape_sandbox("adb", "-s", serial, "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", uri, it->app).release();

		connect(process, &QProcess::finished, process, &QObject::deleteLater);
		process->start();
	});

	process->start();
}

#include "moc_adb.cpp"
