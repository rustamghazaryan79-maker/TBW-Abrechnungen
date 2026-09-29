sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"sap/ui/model/json/JSONModel",
	"sap/ui/model/Filter",
	"sap/ui/model/FilterOperator",
	"sap/ui/core/Fragment",
	"sap/m/MessageBox",
	"sap/m/library",
	"../model/formatter"
], function (Controller, JSONModel, Filter, FilterOperator, Fragment, MessageBox, mobileLibrary, formatter) {
	"use strict";

	var PlanningCalendarBuiltInView = mobileLibrary.PlanningCalendarBuiltInView;

	var MAX_PERIOD_DAYS = 400;
	var ALL_STATUSES = ["POSTED", "APPROVED", "SENT"];

	// ---- Datums-Helfer -------------------------------------------------------

	/** OData liefert Edm.DateTime als UTC-Mitternacht – für die Anzeige in lokale Zeit umrechnen */
	function toLocalDate(oUtcDate) {
		return oUtcDate ? new Date(oUtcDate.getUTCFullYear(), oUtcDate.getUTCMonth(), oUtcDate.getUTCDate()) : null;
	}

	/** Für Filter an das Backend: lokales Datum als UTC-Mitternacht */
	function toUtcDate(oLocalDate) {
		return new Date(Date.UTC(oLocalDate.getFullYear(), oLocalDate.getMonth(), oLocalDate.getDate()));
	}

	function addDays(oDate, iDays) {
		var oResult = new Date(oDate.getTime());
		oResult.setDate(oResult.getDate() + iDays);
		return oResult;
	}

	function addMs(oDate, iMs) {
		return new Date(oDate.getTime() + iMs);
	}

	/** Edm.Time kommt im V2-Modell als { ms: 28800000, __edmType: "Edm.Time" } */
	function timeMs(oTime) {
		return oTime && oTime.ms ? oTime.ms : 0;
	}

	function formatTime(iMs) {
		var iMinutes = Math.round(iMs / 60000);
		var sH = String(Math.floor(iMinutes / 60));
		var sM = String(iMinutes % 60);
		return (sH.length < 2 ? "0" + sH : sH) + ":" + (sM.length < 2 ? "0" + sM : sM);
	}

	function countWorkdays(oFrom, oTo) {
		var iCount = 0;
		for (var oDay = new Date(oFrom.getTime()); oDay <= oTo; oDay = addDays(oDay, 1)) {
			if (oDay.getDay() !== 0 && oDay.getDay() !== 6) {
				iCount++;
			}
		}
		return iCount;
	}

	function daysBetween(oFrom, oTo) {
		return Math.round((toUtcDate(oTo) - toUtcDate(oFrom)) / 86400000);
	}

	return Controller.extend("zhr.teamabs.controller.Main", {
		formatter: formatter,

		// ---- Lebenszyklus ------------------------------------------------------

		onInit: function () {
			var oToday = new Date();
			var oFrom = new Date(oToday.getFullYear(), oToday.getMonth(), 1);
			var oTo = new Date(oToday.getFullYear(), oToday.getMonth() + 2, 0); // Ende des Folgemonats

			this._oViewModel = new JSONModel({
				tab: "employees",
				noOrgUnits: false,
				orgUnits: [],
				orgTree: [],
				selectedOrgUnits: [],
				includeSubUnits: true,
				dateFrom: oFrom,
				dateTo: oTo,
				statuses: ALL_STATUSES.slice(),
				employeeQuery: "",
				employees: [],
				selectedPernrs: [],
				absences: [],
				visibleAbsences: [],
				rows: [],
				calendarStart: oFrom,
				employeeCount: 0,
				rowCount: 0,
				absenceCount: 0,
				employeesTitle: "",
				absencesTitle: "",
				selectionInfo: "",
				filterSummary: "",
				detail: {}
			});
			this._oViewModel.setSizeLimit(10000);
			this.getView().setModel(this._oViewModel, "view");
			this.getView().addStyleClass(this.getOwnerComponent().getContentDensityClass());

			this.byId("calendar").setViewKey(PlanningCalendarBuiltInView.OneMonth);

			this._oODataModel = this.getOwnerComponent().getModel();
			this._oODataModel.metadataLoaded().then(this._loadOrgUnits.bind(this));
		},

		// ---- Selektion ---------------------------------------------------------

		/** "Start" in der Filterleiste */
		onSearch: function () {
			this._loadData();
		},

		/** Status oder Mitarbeitersuche geändert – nur clientseitig neu filtern */
		onClientFilterChange: function () {
			this._applyClientFilters();
		},

		onEmployeeSelectionChange: function () {
			this._applyClientFilters();
		},

		onSelectNone: function () {
			this._oViewModel.getProperty("/employees").forEach(function (oEmployee) {
				oEmployee.selected = false;
			});
			this.byId("employeeTable").removeSelections(true);
			this._applyClientFilters();
		},

		onShowCalendar: function () {
			this._oViewModel.setProperty("/calendarStart", this._oViewModel.getProperty("/dateFrom"));
			this._oViewModel.setProperty("/tab", "calendar");
		},

		// ---- Org-Einheiten-Auswahl --------------------------------------------

		onOrgValueHelp: function () {
			var oView = this.getView();
			var mSelected = {};
			this._oViewModel.getProperty("/selectedOrgUnits").forEach(function (oOrg) {
				mSelected[oOrg.Orgeh] = true;
			});
			this._walkOrgTree(function (oNode) {
				oNode.selected = !!mSelected[oNode.Orgeh];
			});
			this._oViewModel.refresh(true);

			if (!this._pOrgDialog) {
				this._pOrgDialog = Fragment.load({
					id: oView.getId(),
					name: "zhr.teamabs.view.OrgUnitDialog",
					controller: this
				}).then(function (oDialog) {
					oView.addDependent(oDialog);
					return oDialog;
				});
			}
			this._pOrgDialog.then(function (oDialog) {
				oDialog.open();
				this.byId("orgUnitTree").expandToLevel(10);
			}.bind(this));
		},

		onOrgSearch: function (oEvent) {
			var sQuery = oEvent.getParameter("newValue");
			var oBinding = this.byId("orgUnitTree").getBinding("items");
			oBinding.filter(sQuery ? [new Filter("Text", FilterOperator.Contains, sQuery)] : []);
			this.byId("orgUnitTree").expandToLevel(10);
		},

		onOrgDialogConfirm: function () {
			var aSelected = [];
			this._walkOrgTree(function (oNode) {
				if (oNode.selected) {
					aSelected.push({ Orgeh: oNode.Orgeh, Text: oNode.Text });
				}
			});
			this._oViewModel.setProperty("/selectedOrgUnits", aSelected);
			this._updateFilterSummary();
			this.byId("orgUnitDialog").close();
		},

		onOrgDialogCancel: function () {
			this.byId("orgUnitDialog").close();
		},

		onOrgTokenUpdate: function (oEvent) {
			if (oEvent.getParameter("type") !== "removed") {
				return;
			}
			var aRemoved = oEvent.getParameter("removedTokens").map(function (oToken) {
				return oToken.getKey();
			});
			var aRemaining = this._oViewModel.getProperty("/selectedOrgUnits").filter(function (oOrg) {
				return aRemoved.indexOf(oOrg.Orgeh) === -1;
			});
			this._oViewModel.setProperty("/selectedOrgUnits", aRemaining);
			this._updateFilterSummary();
		},

		formatOrgNode: function (sText, iEmpCount) {
			return sText + " (" + this._text("orgEmpCount", [iEmpCount || 0]) + ")";
		},

		// ---- Kalender / Details / Export ---------------------------------------

		onAppointmentSelect: function (oEvent) {
			var oAppointment = oEvent.getParameter("appointment");
			if (!oAppointment) {
				return;
			}
			var oData = oAppointment.getBindingContext("view").getObject().absence;
			var oView = this.getView();

			this._oViewModel.setProperty("/detail", {
				title: oData.AbsenceTypeText || oData.AbsenceType || this._text("detailTitle"),
				employee: oData.Name + " (" + oData.Pernr + ")",
				type: oData.AbsenceType ? (oData.AbsenceTypeText || "") + " (" + oData.AbsenceType + ")" : oData.AbsenceTypeText,
				period: this._periodText(oData),
				duration: this._text("detailDurationValue", [formatter.number(oData.Days), formatter.number(oData.Hours)]),
				statusText: formatter.statusText.call(this, oData.Status),
				statusState: formatter.statusState(oData.Status),
				statusIcon: formatter.statusIcon(oData.Status),
				source: formatter.sourceText.call(this, oData.Source)
			});

			if (!this._pDetail) {
				this._pDetail = Fragment.load({
					id: oView.getId(),
					name: "zhr.teamabs.view.AbsenceDetail",
					controller: this
				}).then(function (oPopover) {
					oView.addDependent(oPopover);
					return oPopover;
				});
			}
			this._pDetail.then(function (oPopover) {
				oPopover.openBy(oAppointment);
			});
		},

		onCloseDetail: function () {
			this.byId("absenceDetail").close();
		},

		onExport: function () {
			var that = this;
			var aRows = this._oViewModel.getProperty("/visibleAbsences").map(function (oAbs) {
				return {
					Name: oAbs.Name,
					Pernr: oAbs.Pernr,
					AbsenceType: oAbs.AbsenceType,
					AbsenceTypeText: oAbs.AbsenceTypeText,
					Begin: oAbs.begin,
					End: oAbs.endDay,
					Days: parseFloat(oAbs.Days) || 0,
					Hours: parseFloat(oAbs.Hours) || 0,
					Status: formatter.statusText.call(that, oAbs.Status),
					Source: formatter.sourceText.call(that, oAbs.Source)
				};
			});

			sap.ui.require(["sap/ui/export/Spreadsheet", "sap/ui/export/library"], function (Spreadsheet, exportLibrary) {
				var EdmType = exportLibrary.EdmType;
				var oSheet = new Spreadsheet({
					workbook: {
						columns: [
							{ label: that._text("colName"), property: "Name", type: EdmType.String, width: 25 },
							{ label: that._text("colPernr"), property: "Pernr", type: EdmType.String, width: 10 },
							{ label: that._text("colAbsenceTypeKey"), property: "AbsenceType", type: EdmType.String, width: 8 },
							{ label: that._text("colAbsenceType"), property: "AbsenceTypeText", type: EdmType.String, width: 25 },
							{ label: that._text("colFrom"), property: "Begin", type: EdmType.Date, width: 12 },
							{ label: that._text("colTo"), property: "End", type: EdmType.Date, width: 12 },
							{ label: that._text("colDays"), property: "Days", type: EdmType.Number, scale: 2, width: 8 },
							{ label: that._text("colHours"), property: "Hours", type: EdmType.Number, scale: 2, width: 8 },
							{ label: that._text("colStatus"), property: "Status", type: EdmType.String, width: 14 },
							{ label: that._text("colSource"), property: "Source", type: EdmType.String, width: 20 }
						]
					},
					dataSource: aRows,
					fileName: that._text("exportFileName") + ".xlsx",
					worker: false
				});
				oSheet.build().finally(function () {
					oSheet.destroy();
				});
			});
		},

		// ---- Daten laden -------------------------------------------------------

		_loadOrgUnits: function () {
			this._setBusy(true);
			return this._read("/OrgUnits").then(function (aOrgUnits) {
				this._oViewModel.setProperty("/orgUnits", aOrgUnits);
				this._oViewModel.setProperty("/orgTree", this._buildOrgTree(aOrgUnits));
				this._oViewModel.setProperty("/noOrgUnits", aOrgUnits.length === 0);
				this._updateFilterSummary();
				if (aOrgUnits.length > 0) {
					return this._loadData();
				}
				return undefined;
			}.bind(this)).catch(this._showError.bind(this)).finally(this._setBusy.bind(this, false));
		},

		_loadData: function () {
			var oVM = this._oViewModel;
			var oFrom = oVM.getProperty("/dateFrom");
			var oTo = oVM.getProperty("/dateTo");

			if (!oFrom || !oTo) {
				MessageBox.warning(this._text("msgPeriodMissing"));
				return Promise.resolve();
			}
			if (daysBetween(oFrom, oTo) > MAX_PERIOD_DAYS) {
				MessageBox.warning(this._text("msgPeriodTooLong"));
				return Promise.resolve();
			}

			var aOrgeh = this._getOrgUnitsForQuery();
			var aEmployeeFilters = aOrgeh.length ? [this._orFilter("Orgeh", aOrgeh)] : [];
			var aEmployees = [];

			this._setBusy(true);
			return this._read("/Employees", aEmployeeFilters).then(function (aResult) {
				aEmployees = aResult.map(function (oEmployee) {
					return Object.assign({}, oEmployee, { selected: false, absenceDays: 0 });
				});
				if (aEmployees.length === 0) {
					return [];
				}
				var aPernr = aEmployees.map(function (oEmployee) {
					return oEmployee.Pernr;
				});
				return this._read("/Absences", [new Filter({
					filters: [
						this._orFilter("Pernr", aPernr),
						new Filter("EndDate", FilterOperator.GE, toUtcDate(oFrom)),
						new Filter("BeginDate", FilterOperator.LE, toUtcDate(oTo))
					],
					and: true
				})]);
			}.bind(this)).then(function (aAbsences) {
				oVM.setProperty("/employees", aEmployees);
				oVM.setProperty("/absences", aAbsences.map(this._prepareAbsence, this));
				oVM.setProperty("/calendarStart", oFrom);
				this.byId("employeeTable").removeSelections(true);
				this._updateFilterSummary();
				this._applyClientFilters();
			}.bind(this)).catch(this._showError.bind(this)).finally(this._setBusy.bind(this, false));
		},

		/** Ausgewählte Org-Einheiten, ggf. inkl. aller Untereinheiten. Leer = alle eigenen. */
		_getOrgUnitsForQuery: function () {
			var oVM = this._oViewModel;
			var aSelected = oVM.getProperty("/selectedOrgUnits").map(function (oOrg) {
				return oOrg.Orgeh;
			});
			if (aSelected.length === 0 || !oVM.getProperty("/includeSubUnits")) {
				return aSelected;
			}

			var mChildren = {};
			oVM.getProperty("/orgUnits").forEach(function (oOrg) {
				(mChildren[oOrg.Parent] = mChildren[oOrg.Parent] || []).push(oOrg.Orgeh);
			});
			var mResult = {};
			var aQueue = aSelected.slice();
			while (aQueue.length) {
				var sOrgeh = aQueue.shift();
				if (!mResult[sOrgeh]) {
					mResult[sOrgeh] = true;
					aQueue = aQueue.concat(mChildren[sOrgeh] || []);
				}
			}
			return Object.keys(mResult);
		},

		_prepareAbsence: function (oAbs) {
			var oBegin = toLocalDate(oAbs.BeginDate);
			var oEndDay = toLocalDate(oAbs.EndDate);
			var iBeginMs = timeMs(oAbs.BeginTime);
			var iEndMs = timeMs(oAbs.EndTime);
			var bPartial = oBegin.getTime() === oEndDay.getTime() && iEndMs > iBeginMs;

			return Object.assign({}, oAbs, {
				begin: oBegin,
				endDay: oEndDay,
				partial: bPartial,
				// Ganztägig: Ende exklusiv am Folgetag 00:00, damit der letzte Tag voll gefüllt ist
				start: bPartial ? addMs(oBegin, iBeginMs) : oBegin,
				end: bPartial ? addMs(oEndDay, iEndMs) : addDays(oEndDay, 1)
			});
		},

		// ---- Clientseitige Aufbereitung ----------------------------------------

		_applyClientFilters: function () {
			var oVM = this._oViewModel;
			var oFrom = oVM.getProperty("/dateFrom");
			var oTo = oVM.getProperty("/dateTo");
			var aStatuses = oVM.getProperty("/statuses");
			var sQuery = (oVM.getProperty("/employeeQuery") || "").trim().toLowerCase();
			var aEmployees = oVM.getProperty("/employees");
			var aAbsences = oVM.getProperty("/absences");

			var fnMatches = function (oEmployee) {
				return !sQuery ||
					oEmployee.Name.toLowerCase().indexOf(sQuery) !== -1 ||
					oEmployee.Pernr.indexOf(sQuery) !== -1;
			};
			var fnStatusVisible = function (oAbs) {
				return aStatuses.indexOf(oAbs.Status) !== -1;
			};

			// Abwesenheitstage je Mitarbeiter im Zeitraum
			var mDays = {};
			aAbsences.filter(fnStatusVisible).forEach(function (oAbs) {
				mDays[oAbs.Pernr] = (mDays[oAbs.Pernr] || 0) + this._daysInPeriod(oAbs, oFrom, oTo);
			}, this);
			aEmployees.forEach(function (oEmployee) {
				oEmployee.absenceDays = mDays[oEmployee.Pernr] || 0;
			});

			// Tabelle nach Suche filtern (Auswahl bleibt erhalten)
			var oBinding = this.byId("employeeTable").getBinding("items");
			if (oBinding) {
				oBinding.filter(sQuery ? [new Filter({
					filters: [
						new Filter("Name", FilterOperator.Contains, sQuery),
						new Filter("Pernr", FilterOperator.Contains, sQuery)
					],
					and: false
				})] : []);
			}

			// Kalender zeigt die Auswahl – ohne Auswahl alle Mitarbeiter
			var aSelected = aEmployees.filter(function (oEmployee) {
				return oEmployee.selected;
			});
			var aShown = (aSelected.length ? aSelected : aEmployees).filter(fnMatches).sort(function (a, b) {
				return a.Name.localeCompare(b.Name);
			});
			var mShown = {};
			aShown.forEach(function (oEmployee) {
				mShown[oEmployee.Pernr] = true;
			});

			var aVisibleAbsences = aAbsences.filter(function (oAbs) {
				return mShown[oAbs.Pernr] && fnStatusVisible(oAbs);
			});

			var aRows = aShown.map(function (oEmployee) {
				return {
					pernr: oEmployee.Pernr,
					title: oEmployee.Name,
					text: [oEmployee.OrgehText, oEmployee.PlansText].filter(Boolean).join(" · "),
					appointments: aVisibleAbsences.filter(function (oAbs) {
						return oAbs.Pernr === oEmployee.Pernr;
					}).map(this._toAppointment, this)
				};
			}, this);

			var iVisibleEmployees = aEmployees.filter(fnMatches).length;
			oVM.setProperty("/selectedPernrs", aSelected.map(function (oEmployee) {
				return oEmployee.Pernr;
			}));
			oVM.setProperty("/rows", aRows);
			oVM.setProperty("/visibleAbsences", aVisibleAbsences);
			oVM.setProperty("/employeeCount", aEmployees.length);
			oVM.setProperty("/rowCount", aRows.length);
			oVM.setProperty("/absenceCount", aVisibleAbsences.length);
			oVM.setProperty("/employeesTitle", this._text("employeesTitle", [iVisibleEmployees]));
			oVM.setProperty("/absencesTitle", this._text("absencesTitle", [aVisibleAbsences.length]));
			oVM.setProperty("/selectionInfo", aSelected.length ?
				this._text("employeesSelectedInfo", [aSelected.length, aEmployees.length]) :
				this._text("employeesNoneSelectedInfo", [aEmployees.length]));
			oVM.refresh(true);
		},

		_toAppointment: function (oAbs) {
			var sStatus = formatter.statusText.call(this, oAbs.Status);
			var sType = oAbs.AbsenceTypeText || oAbs.AbsenceType;
			var sText = oAbs.partial ?
				sStatus + ", " + this._text("halfDay", [formatTime(timeMs(oAbs.BeginTime)), formatTime(timeMs(oAbs.EndTime))]) :
				sStatus;

			return {
				start: oAbs.start,
				end: oAbs.end,
				title: sType,
				text: sText,
				icon: oAbs.Status === "SENT" ? "sap-icon://pending" : "",
				color: formatter.statusColor[oAbs.Status],
				tooltip: sType + "\n" + this._periodText(oAbs) + "\n" + sStatus,
				absence: oAbs
			};
		},

		/** Arbeitstage (Mo–Fr) einer Abwesenheit, die in den Zeitraum fallen */
		_daysInPeriod: function (oAbs, oFrom, oTo) {
			if (oAbs.begin >= oFrom && oAbs.endDay <= oTo) {
				return parseFloat(oAbs.Days) || 0;
			}
			var oStart = oAbs.begin > oFrom ? oAbs.begin : oFrom;
			var oEnd = oAbs.endDay < oTo ? oAbs.endDay : oTo;
			return oStart <= oEnd ? countWorkdays(oStart, oEnd) : 0;
		},

		_periodText: function (oAbs) {
			var sPeriod = formatter.period(oAbs.begin, oAbs.endDay);
			if (oAbs.partial) {
				sPeriod += ", " + this._text("halfDay", [formatTime(timeMs(oAbs.BeginTime)), formatTime(timeMs(oAbs.EndTime))]);
			}
			return sPeriod;
		},

		_updateFilterSummary: function () {
			var oVM = this._oViewModel;
			var aOrgs = oVM.getProperty("/selectedOrgUnits");
			var sOrgs = aOrgs.length ?
				aOrgs.map(function (oOrg) { return oOrg.Text; }).join(", ") :
				this._text("filterOrgUnitsPlaceholder");
			oVM.setProperty("/filterSummary", sOrgs + " · " +
				formatter.period(oVM.getProperty("/dateFrom"), oVM.getProperty("/dateTo")));
		},

		// ---- Org-Baum ----------------------------------------------------------

		_buildOrgTree: function (aOrgUnits) {
			var mNodes = {};
			aOrgUnits.forEach(function (oOrg) {
				mNodes[oOrg.Orgeh] = {
					Orgeh: oOrg.Orgeh,
					Text: oOrg.Text || oOrg.ShortText || oOrg.Orgeh,
					EmpCount: oOrg.EmpCount,
					selected: false,
					children: []
				};
			});
			var aRoots = [];
			aOrgUnits.forEach(function (oOrg) {
				var oParent = mNodes[oOrg.Parent];
				if (oParent && oOrg.Parent !== oOrg.Orgeh) {
					oParent.children.push(mNodes[oOrg.Orgeh]);
				} else {
					aRoots.push(mNodes[oOrg.Orgeh]);
				}
			});
			return aRoots;
		},

		_walkOrgTree: function (fnVisit) {
			var fnWalk = function (aNodes) {
				aNodes.forEach(function (oNode) {
					fnVisit(oNode);
					fnWalk(oNode.children || []);
				});
			};
			fnWalk(this._oViewModel.getProperty("/orgTree"));
		},

		// ---- Technik -----------------------------------------------------------

		_orFilter: function (sPath, aValues) {
			return new Filter({
				filters: aValues.map(function (sValue) {
					return new Filter(sPath, FilterOperator.EQ, sValue);
				}),
				and: false
			});
		},

		_read: function (sPath, aFilters) {
			var oModel = this._oODataModel;
			return new Promise(function (resolve, reject) {
				oModel.read(sPath, {
					filters: aFilters || [],
					success: function (oData) {
						resolve(oData.results || []);
					},
					error: reject
				});
			});
		},

		_setBusy: function (bBusy) {
			this.byId("page").setBusy(bBusy);
		},

		_showError: function (oError) {
			var sMessage = this._text("msgLoadError");
			try {
				sMessage = JSON.parse(oError.responseText).error.message.value || sMessage;
			} catch (e) {
				// keine Gateway-Fehlermeldung im Body – Standardtext verwenden
			}
			MessageBox.error(sMessage);
		},

		_text: function (sKey, aArgs) {
			return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
		}
	});
});
