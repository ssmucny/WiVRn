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

#pragma once

#include <QAbstractListModel>
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class adb : public QAbstractListModel
{
	Q_OBJECT
	QML_NAMED_ELEMENT(Adb)
	QML_SINGLETON

	struct device
	{
		QString serial;
		QString state;
		QString app;
		std::map<QString, QString> properties;
		bool is_wivrn_installed = false;
	};

	Q_PROPERTY(bool adbInstalled READ adbInstalled NOTIFY adbInstalledChanged)

	bool m_adb_installed;
	std::vector<device> m_android_devices;

	QTimer m_poll_devices_timer;

	void on_poll_devices_timeout();
	std::unique_ptr<QProcess> m_poll_devices_process;
	void on_poll_devices_process_finished(int exit_code, QProcess::ExitStatus exit_status);

	std::unique_ptr<QProcess> m_check_adb_installed;
	void on_check_adb_installed_finished(int exit_code, QProcess::ExitStatus exit_status);

public:
	enum Roles
	{
		RoleSerial = Qt::UserRole + 1,
		RoleIsWivrnInstalled,
		RoleManufacturer,
		RoleModel,
		RoleState,
		RoleProduct,
		RoleDevice,
	};
	adb();

	bool adbInstalled() const
	{
		return m_adb_installed;
	}

	Q_INVOKABLE void checkIfAdbIsInstalled();
	// Q_INVOKABLE bool installWivrnApk(QString serial, QString apkPath);
	Q_INVOKABLE void startUsbConnection(QString serial, QString pin);

	int rowCount(const QModelIndex & parent) const override
	{
		return m_android_devices.size();
	}

	QVariant data(const QModelIndex & index, int role) const override;

protected:
	QHash<int, QByteArray> roleNames() const override;

Q_SIGNALS:
	void adbInstalledChanged(bool);

private:
	void add_device(device && dev);

	void add_device_on_package_list(int exit_code, QProcess::ExitStatus exit_status, QProcess * process, device && dev);
	void add_device_on_getprop(int exit_code, QProcess::ExitStatus exit_status, QProcess * process, device && dev);
};
