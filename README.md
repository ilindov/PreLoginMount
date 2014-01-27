## PreLoginMount



#### 1. What is PreLoginMount

	PreLoginMount is a simple program that allows the user to mount a (usually encrypted) disk image, sparse image or sparse bundle before a user is logged in Mac OSX. This is made possible by showing the PreLoginMount window on the login screen.


#### 2. IMPORTANT!!!

	PreLoginMount runs as the root user, so be careful with the configuration.


#### 3. Disclaimer

	**Although I use this software on a daily basis, I do not guarantee that it won’t lead to data loss, corruption, system or security flaws, so by installing it you agree that you USE IT AT YOUR OWN RISK.**


#### 4. Licence

 PreLoginMount - mount disk images, sparse images and sparse bundles before user logon.
 Copyright (C) 2014  Iliya Lindov

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


#### 5. Compatibility

	This software is developed and tested on Mavericks.
	I don't have the possibility to test it on older versions, but it should work on Lion and above.


#### 6. Installation

	**!!! PLEASE, DO A FULL SYSTEM BACKUP BEFORE INSTALLATION !!!**

	The software consists of one application and two property list files:
	
	PreLoginMount.app
	PreLoginMount.plist
	com.lindov.osx.PreLoginMount.plist

	Installation should be done with a user with administrative rights from terminal.
	- Open Terminal
	- Unzip the archive, e.g:
		*\# unzip PreLoginMount-current.zip*
	- Go to the unzipped directory
		*\# cd ./PreLoginMount-current/*
	- Copy PreLoginMount.plist to /etc/
		*\# sudo cp PreLoginMount.plist /etc/*
	- Copy com.lindov.osx.PreLoginMount.plist to /Library/LaunchAgents/
		*\# sudo cp com.lindov.osx.PreLoginMount.plist /Library/LaunchAgents/*
	- Copy PreLoginMount.app to /Library/PrivilegedHelperTools
		*\# sudo cp -R PreLoginMount.app /Library/PrivilegedHelperTools/*
	- Change ownership and permissions of the files
		*\# chown -R root:wheel /etc/PreLoginMount.plist /Library/LaunchAgents/com.lindov.osx.PreLoginMount.plist /Library/PrivilegedHelperTools/PreLoginMount.app*
		*\# chmod 644 /etc/PreLoginMount.plist /Library/LaunchAgents/com.lindov.osx.PreLoginMount.plist*


#### 7. Configuration
	
	The only file that the user should edit is ‘/etc/PreLoginMount.plist’. It contains three sections - Meta, Common and Users.
	The Meta section is edited by the software, so no need of manual modifications here.
	The Common section contains some common settings that must be configured before running the software. Usually the predefined values are correct, but please double check. These are:
	- PathToSh - path to the ’sh’ shell executable.
	- PathToPrintf - path to the ‘printf’ executable.
	- PathToHdiutil - path to the ‘hdiutil’ executable.
	- FlagDirectory - not used yet.

	The Users section contains specific settings for each user. There are two example users defined in the file, namely User 1 and User 2, so please edit it to match your setup.
	- DiskImage - path to the image that will be mounted.
	- MountPoint - where the image should be mounted. If left empty the image is mounted under /Volumes
	- ReadOnly - mount image read-only.
	- FsckOnMount - check filesystem integrity on mount. Can be set or unset from the UI. 
	- VerifyImage - verify the image checksum on mount.
	- IgnoreBadChecksum - Set if the mount should be done if verified image’s checksum is bad.
	- Browseable - If set to true, the volume will be visible in applications (like in Finder’s DEVICES).
	- HonorOwners - Specify if the filesystem’s contents’ ownership should be honored or not.
	- Encrypted - Specifies if the image is encrypted or not.
	- VerboseMode - Enable verbose mode on startup. Can be set or unset from the UI.


#### 8. User’s home directory in sparse bundle image.
	
	The main purpose of this application is to make it possible for the user’s home directory to be in an encrypted sparse bundle image.
	Please, consider the following guidelines.

	- It’s better if your disk images are owned and only writable by the root user.
	- 'MountPoint' parameter in ‘/etc/PreLoginMount.plist’ should be empty. This way the user's home would be in '/Volumes/<Volume name>'

	Installation steps:
	- Install and configure the program as described in p.6 and p.7.
	- Create sparse bundle using 'Disk Utility' - 'File -> New -> Blank Disk Image...'. 
	- Set the filename on top.
	- Set volume name 'Name' to something meaningful, e.g. 'John's Home'.
	- Set preferred size 'Size'. Bear in mind that you can reclaim space later, so make it big enough to fit your data and have enough free space in your home directory.
	- Set 'Format' to 'Mac OS Extended (Journaled)'.
	- Set 'Encryption' to 128-bit.
	- Set 'Partition' to 'Single Partition - GUID Partition Map'
	- Set 'Image Format' to 'sparse bundle disk image'.
	- Click 'Create' and close the Disk Utility after the sparse bundle is created.
	- Move the sparse bundle outside of your home directory, e.g. in /opt/PreLoginMount/disks
		*\# sudo mkdir -p /opt/PreLoginMount/disks*
		*\# sudo mv <filename>.sparsebundle /opt/PreLoginMount/disks*
		*\# chown -R root:wheel /opt/PreLoginMount/disks/<filename>.sparsebundle*
	- Open 'System Preferences',  'Users & Groups' and create a new user with administrative rights.
	- Log out of your account and login in the temporary account that you've create in the previous step.
	- Attach the sparse bundle. Open terminal:
		*\# sudo hdiutil attach -stdinpass /opt/PreLoginMount/disks/<filename>.sparsebundle*
		NOTE: The first password prompt comes from 'sudo' - it requests the user's password.
	- Open 'System Preferences',  'Users & Groups' and right-click on your user.
	- Click on 'Advanced Options...'.
	- Set 'Home Directory' to '/Volumes/<Volume name>', e.g. '/Volumes/John's Home'
	- Copy all files from old home directory to the new one, e.g.:
		*\# cd <old_home>*
		*\# find ./ -xdev -print0 | cpio -pa0 <new_home>*
	- Log out and try to login with your user.
