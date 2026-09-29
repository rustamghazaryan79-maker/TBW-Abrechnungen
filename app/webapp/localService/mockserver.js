sap.ui.define([
	"sap/ui/core/util/MockServer",
	"sap/base/Log"
], function (MockServer, Log) {
	"use strict";

	var ROOT_URI = "/sap/opu/odata/sap/ZHR_TEAMABS_SRV/";
	var DAY = 24 * 60 * 60 * 1000;

	var ABSENCE_TYPES = [
		{ code: "0100", text: "Erholungsurlaub" },
		{ code: "0100", text: "Erholungsurlaub" },
		{ code: "0100", text: "Erholungsurlaub" },
		{ code: "0300", text: "Zeitausgleich" },
		{ code: "0500", text: "Sonderurlaub" },
		{ code: "0700", text: "Fortbildung" }
	];

	// Einfacher deterministischer Zufall, damit die Mockdaten bei jedem Start gleich aussehen
	function createRandom(iSeed) {
		var iState = iSeed;
		return function () {
			iState = (iState * 1103515245 + 12345) % 2147483648;
			return iState / 2147483648;
		};
	}

	function utcDate(oDate) {
		return Date.UTC(oDate.getFullYear(), oDate.getMonth(), oDate.getDate());
	}

	function isWeekend(iUtc) {
		var iDay = new Date(iUtc).getUTCDay();
		return iDay === 0 || iDay === 6;
	}

	function countWorkdays(iFrom, iTo) {
		var iCount = 0;
		for (var i = iFrom; i <= iTo; i += DAY) {
			if (!isWeekend(i)) {
				iCount++;
			}
		}
		return iCount;
	}

	/**
	 * Abwesenheiten rund um das heutige Datum erzeugen:
	 * Vergangenes ist gebucht, Zukünftiges teils genehmigt, teils noch beantragt.
	 */
	function buildAbsences(aEmployees) {
		var iToday = utcDate(new Date());
		var aResult = [];

		aEmployees.forEach(function (oEmployee, iIndex) {
			var fnRandom = createRandom(Number(oEmployee.Pernr) * 7 + 3);
			var iCursor = iToday - 45 * DAY + Math.floor(fnRandom() * 20) * DAY;
			var iNo = 0;

			while (iCursor < iToday + 150 * DAY) {
				var oType = ABSENCE_TYPES[Math.floor(fnRandom() * ABSENCE_TYPES.length)];
				var iLength = oType.code === "0100" ? 3 + Math.floor(fnRandom() * 9) : 1 + Math.floor(fnRandom() * 2);
				var iBegin = iCursor;
				while (isWeekend(iBegin)) {
					iBegin += DAY;
				}
				var iEnd = iBegin + (iLength - 1) * DAY;
				while (isWeekend(iEnd)) {
					iEnd -= DAY;
				}
				if (iEnd < iBegin) {
					iEnd = iBegin;
				}

				var sStatus = "POSTED";
				var sSource = "IT";
				if (iBegin > iToday + 10 * DAY) {
					var fStatus = fnRandom();
					if (fStatus < 0.35) {
						sStatus = "SENT";
						sSource = "ARQ";
					} else if (fStatus < 0.6) {
						sStatus = "APPROVED";
						sSource = "ARQ";
					}
				}

				// Zeitausgleich gelegentlich nur halbtags
				var bHalfDay = oType.code === "0300" && iBegin === iEnd && fnRandom() < 0.5;
				var iDays = bHalfDay ? 0.5 : countWorkdays(iBegin, iEnd);

				var sId = sSource + oEmployee.Pernr + String(++iNo).padStart(3, "0");
				aResult.push({
					// Typinfo, damit das ODataModel Datum/Zeit korrekt umwandelt
					__metadata: {
						id: ROOT_URI + "Absences('" + sId + "')",
						uri: ROOT_URI + "Absences('" + sId + "')",
						type: "ZHR_TEAMABS_SRV.Absence"
					},
					AbsenceId: sId,
					Pernr: oEmployee.Pernr,
					Name: oEmployee.Name,
					AbsenceType: oType.code,
					AbsenceTypeText: oType.text,
					BeginDate: "/Date(" + iBegin + ")/",
					EndDate: "/Date(" + iEnd + ")/",
					BeginTime: bHalfDay ? "PT08H00M00S" : "PT00H00M00S",
					EndTime: bHalfDay ? "PT12H00M00S" : "PT00H00M00S",
					Days: iDays.toFixed(2),
					Hours: (iDays * 7.8).toFixed(2),
					Status: sStatus,
					Source: sSource
				});

				iCursor = iEnd + (12 + Math.floor(fnRandom() * 35) + iIndex) * DAY;
			}
		});

		return aResult;
	}

	return {
		init: function () {
			return new Promise(function (resolve, reject) {
				var sLocalService = sap.ui.require.toUrl("zhr/teamabs/localService");

				MockServer.config({
					autoRespond: true,
					autoRespondAfter: 300
				});

				var oMockServer = new MockServer({ rootUri: ROOT_URI });
				oMockServer.simulate(sLocalService + "/metadata.xml", {
					sMockdataBaseUrl: sLocalService + "/mockdata",
					aEntitySetsNames: ["OrgUnits", "Employees"],
					bGenerateMissingMockData: false
				});

				var aEmployees = oMockServer.getEntitySetData("Employees");
				oMockServer.setEntitySetData("Absences", buildAbsences(aEmployees));

				oMockServer.start();
				Log.info("Mockserver läuft unter " + ROOT_URI);
				resolve();
			});
		}
	};
});
