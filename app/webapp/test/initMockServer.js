sap.ui.define([
	"zhr/teamabs/localService/mockserver",
	"sap/m/MessageBox"
], function (mockserver, MessageBox) {
	"use strict";

	mockserver.init().catch(function (oError) {
		MessageBox.error(oError.message);
	}).finally(function () {
		sap.ui.require(["sap/ui/core/ComponentSupport"]);
	});
});
