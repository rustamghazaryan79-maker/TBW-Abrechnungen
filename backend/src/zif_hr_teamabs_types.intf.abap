"! Gemeinsame Typen für die Team-Abwesenheits-App (OData-Service ZHR_TEAMABS_SRV)
INTERFACE zif_hr_teamabs_types
  PUBLIC.

  "! Status einer Abwesenheit, wie ihn die App anzeigt
  CONSTANTS:
    BEGIN OF gc_status,
      posted   TYPE char12 VALUE 'POSTED',   " in IT2001 gebucht
      approved TYPE char12 VALUE 'APPROVED', " Antrag genehmigt, noch nicht gebucht
      sent     TYPE char12 VALUE 'SENT',     " Antrag gestellt, wartet auf Genehmigung
    END OF gc_status.

  "! Herkunft einer Abwesenheit
  CONSTANTS:
    BEGIN OF gc_source,
      infotype TYPE char4 VALUE 'IT',  " PA2001
      request  TYPE char4 VALUE 'ARQ', " Abwesenheitsantrag (PTARQ / PTREQ_*)
    END OF gc_source.

  TYPES:
    BEGIN OF ty_org_unit,
      orgeh      TYPE orgeh,
      parent     TYPE orgeh,
      short_text TYPE short_d,
      text       TYPE stext,
      hier_level TYPE i,
      is_root    TYPE abap_bool,
      emp_count  TYPE i,
    END OF ty_org_unit,
    tt_org_unit TYPE STANDARD TABLE OF ty_org_unit WITH DEFAULT KEY,

    BEGIN OF ty_employee,
      pernr      TYPE persno,
      ename      TYPE emnam,
      orgeh      TYPE orgeh,
      orgeh_text TYPE stext,
      plans      TYPE plans,
      plans_text TYPE stext,
      werks      TYPE persa,
      btrtl      TYPE btrtl,
    END OF ty_employee,
    tt_employee TYPE STANDARD TABLE OF ty_employee WITH DEFAULT KEY,

    BEGIN OF ty_absence,
      absence_id TYPE char50,
      pernr      TYPE persno,
      ename      TYPE emnam,
      awart      TYPE awart,
      awart_text TYPE abwtxt,
      begda      TYPE begda,
      endda      TYPE endda,
      beguz      TYPE beguz,
      enduz      TYPE enduz,
      abwtg      TYPE abwtg,
      stdaz      TYPE abstd,
      status     TYPE char12,
      source     TYPE char4,
    END OF ty_absence,
    tt_absence TYPE STANDARD TABLE OF ty_absence WITH DEFAULT KEY,

    tt_orgeh_range TYPE RANGE OF orgeh,
    tt_pernr_range TYPE RANGE OF persno.

ENDINTERFACE.
