/*
 * Panopticon - A libre disassembler (https://panopticon.re/)
 * Copyright (C) 2014-2015 Kai Michaelis
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
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick.Controls 1.1
import QtQuick.Dialogs 1.2
import QtQuick.Layouts 1.1
import QtQuick 2.1
import Panopticon 1.0

ApplicationWindow {
	id: mainWindow

	property string savePath: ""

	MessageDialog {
		id: errorDialog
		title: "Error"
		icon: StandardIcon.Critical
		standardButtons: StandardButton.Ok
	}

	MessageDialog {
		id: saveStaleDialog
		title: "Unsaved changes"
		text: "Do you want to save the changes made to the current project?"
		icon: StandardIcon.Question
		standardButtons: StandardButton.Yes | StandardButton.No | StandardButton.Abort

		property var next: function() {}

		onYes: {
			if(mainWindow.savePath != "") {
				var res = JSON.parse(Panopticon.snapshotProject(mainWindow.savePath));

				if (res.status == "ok") {
					next()
				} else {
					errorDialog.text = res.error;
					errorDialog.open()
				}
			} else {
				fileSaveDialog.next = saveStaleDialog.next
				fileSaveDialog.open()
			}
		}

		onNo: {
			next()
		}

		onRejected: {}
	}

	function saveStalePanopticon(next) {
		if(Panopticon.state != "NEW" && Panopticon.dirty != 0) {
			saveStaleDialog.next = next
			saveStaleDialog.open()
		} else {
			next()
		}
	}

	title: "Panopticon"
	height: 1000
	width: 1000
	visible: true

	menuBar: MenuBar {
		Menu {
			title: "Project"
			Menu {
				title: "New..."

				MenuItem {
					text: "...from ELF executable"
					shortcut: "Ctrl+E"
					enabled: Panopticon.state == "NEW"
					onTriggered: {
						saveStalePanopticon(function() {
							fileNewDialog.next = function(path) {
								var res = JSON.parse(Panopticon.createElfProject(path))

								if(res.status == "ok") {
									loader.setSource("workspace/Workspace.qml")
								} else {
									errorDialog.text = res.error;
									errorDialog.open();
								}
							};
							fileNewDialog.open()
						})
					}
				}

				MenuItem {
					text: "...from dump file"
					shortcut: "Ctrl+A"
					enabled: Panopticon.state == "NEW"
					onTriggered: {
						saveStalePanopticon(function() {
							fileNewDialog.next = function(path) {
								targetSelectionDialog.next = function(target) {
									var res = JSON.parse(Panopticon.createRawProject(path,target));

									if(res.status == "ok") {
										loader.setSource("workspace/Workspace.qml")
									} else {
										errorDialog.text = res.error;
										errorDialog.open();
									}
								};

								targetSelectionDialog.open();
								targetSelectionDialog.width = targetSelectionDialog.contentItem.width
								targetSelectionDialog.height = targetSelectionDialog.contentItem.height
								targetSelectionDialog.x = (mainWindow.width - targetSelectionDialog.width) / 2
								targetSelectionDialog.y = (mainWindow.height - targetSelectionDialog.height) / 2
							}
							fileNewDialog.open()
						})
					}
				}

				MenuItem {
					text: "...from MOS-6502 binary image"
					shortcut: "Ctrl+M"
					enabled: Panopticon.state == "NEW"
					onTriggered: {
						saveStalePanopticon(function() {
							fileNewDialog.next = function(path) {
								var res = JSON.parse(Panopticon.createMos6502Project(path))

								if(res.status == "ok") {
									loader.setSource("workspace/Workspace.qml")
								} else {
									errorDialog.text = res.error;
									errorDialog.open();
								}
							};
							fileNewDialog.open()
						})
					}
				}


			}

			MenuItem {
				text: "Open"
				shortcut: "Ctrl+O"
				enabled: Panopticon.state == "NEW"
				onTriggered: {
					saveStalePanopticon(fileOpenDialog.open);
				}
			}
			MenuItem {
				text: "Save"
				shortcut: "Ctrl+S"
				enabled: Panopticon.dirty != 0 && Panopticon.state != "NEW"
				onTriggered: {
					if(mainWindow.savePath != "") {
						var res = JSON.parse(Panopticon.snapshotProject(mainWindow.savePath));

						if(res.status == "err") {
							errorDialog.text = res.error;
							errorDialog.open();
						}
					} else {
						fileSaveDialog.open()
					}
				}
			}
			MenuItem {
				text: "Save As"
				shortcut: "Ctrl+Shift+S"
				enabled: Panopticon.state != "NEW"
				onTriggered: { fileSaveDialog.open() }
			}

			MenuSeparator {}

			MenuItem {
				text: "Quit"
				shortcut: "Ctrl+Q"
				onTriggered: {
					saveStalePanopticon(Qt.quit)
				}
			}
		}
	}

	Dialog {
		id: targetSelectionDialog
		title: "Select target architecture..."
		standardButtons: StandardButton.Ok | StandardButton.Cancel

		property var next: function() {}

		RowLayout {
			Label {
				text: "Architecture:"
			}

			ComboBox {
				id: targetComboBox
				Layout.preferredWidth: 150
				model: {
					console.log(Panopticon.allTargets());
					var res = JSON.parse(Panopticon.allTargets());

					if(res.status == "ok") {
						return res.payload;
					} else {
						console.log(res.error);
						return [];
					}
				}
			}
		}

		onAccepted: {
			next(targetComboBox.currentText);
		}
	}

	FileDialog {
		id: fileSaveDialog
		title: "Save current project to..."
		selectExisting: false
		selectFolder: false
		nameFilters: [ "Panopticon projects (*.panop)", "All files (*)" ]

		property var next: function() {}

		onAccepted: {
			var path = fileSaveDialog.fileUrls.toString().substring(7)

			if (path.substring(path.length - 6) != ".panop") {
				path += ".panop"
			}

			if (mainWindow.savePath == "") {
				mainWindow.savePath = path;
			}

			var res = JSON.parse(Panopticon.snapshotProject(path))

			if(res.state == "ok") {
				next()
			} else {
				errorDialog.text = res.error;
				errorDialog.open();
			}
		}
	}

	FileDialog {
		id: fileOpenDialog
		title: "Open new project..."
		selectExisting: true
		selectFolder: false
		nameFilters: [ "Panopticon projects (*.panop)", "All files (*)" ]

		property var next: function() {}

		onAccepted: {
			// cut off the "file://" part
			var path = fileOpenDialog.fileUrls.toString().substring(7)
			var res = JSON.parse(Panopticon.openProject(path));

			if(res.status == "ok") {
				loader.setSource("workspace/Workspace.qml")
				next()
			} else {
				errorDialog.text = res.error;
				errorDialog.open();
			}
		}
	}

	FileDialog {
		id: fileNewDialog
		title: "Start new project..."
		selectExisting: true
		selectFolder: false

		property var next: null

		onAccepted: {
			// cut off the "file://" part
			var path = fileNewDialog.fileUrls.toString().substring(7)
			next(path)
		}
	}

	Loader {
		focus: true
		id: loader
		anchors.fill: parent
		sourceComponent: Item {
			anchors.fill: parent

			Item {
				anchors.centerIn: parent
				height: childrenRect.height
				width: childrenRect.width

				Image {
					id: panopLogo
					source: "panop.png"
				}

				Text {
					anchors.verticalCenter: panopLogo.verticalCenter
					anchors.left: panopLogo.right
					anchors.leftMargin: 10
					text: "PANOPTICON"
					color: "#1e1e1e";
					font {
						pixelSize: panopLogo.height
					}
				}
			}
		}
	}

	Component.onCompleted: {
		if(Panopticon.state != "NEW") {
			loader.setSource("workspace/Workspace.qml")
		}
	}
}
