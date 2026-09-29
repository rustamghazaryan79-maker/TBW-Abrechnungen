sap.ui.define([
	"sap/ui/core/format/DateFormat"
], function (DateFormat) {
	"use strict";

	var oDateFormat = DateFormat.getDateInstance({ style: "medium" });

	var mStatusState = {
		POSTED: "Success",
		APPROVED: "Information",
		SENT: "Warning"
	};

	var mStatusIcon = {
		POSTED: "sap-icon://accept",
		APPROVED: "sap-icon://approvals",
		SENT: "sap-icon://pending"
	};

	var formatter = {
		/** Farben im Kalender (fest, damit Legende und Termine sicher passen) */
		statusColor: {
			POSTED: "#256f3a",
			APPROVED: "#0070f2",
			SENT: "#e76500"
		},

		statusText: function (sStatus) {
			if (!sStatus) {
				return "";
			}
			return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText("status" + sStatus);
		},

		statusState: function (sStatus) {
			return mStatusState[sStatus] || "None";
		},

		statusIcon: function (sStatus) {
			return mStatusIcon[sStatus] || "";
		},

		sourceText: function (sSource) {
			if (!sSource) {
				return "";
			}
			return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText("source" + sSource);
		},

		date: function (oDate) {
			return oDate ? oDateFormat.format(oDate) : "";
		},

		period: function (oFrom, oTo) {
			if (!oFrom) {
				return "";
			}
			if (!oTo || oFrom.getTime() === oTo.getTime()) {
				return oDateFormat.format(oFrom);
			}
			return oDateFormat.format(oFrom) + " – " + oDateFormat.format(oTo);
		},

		number: function (vValue) {
			var fValue = parseFloat(vValue);
			if (isNaN(fValue)) {
				return "";
			}
			return fValue.toLocaleString("de-DE", { minimumFractionDigits: 0, maximumFractionDigits: 2 });
		}
	};

	return formatter;
});
