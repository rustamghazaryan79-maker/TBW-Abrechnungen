"! Liefert die eigene Org-Hierarchie des angemeldeten Benutzers
"! (alle Org-Einheiten, die er als Leiter führt, inkl. Untereinheiten)
"! und die Mitarbeiter darin.
"!
"! Ablauf:
"!   SY-UNAME --(IT0105 Subtyp 0001)--> Personalnummer
"!   Personalnummer --(Auswertungsweg SAP_MANG: P-B008-S-A012-O)--> geführte Org-Einheiten
"!   je geführter Org-Einheit --(Auswertungsweg ORGEH: O-B002-O)--> Untereinheiten
"!   Mitarbeiter = aktive Personen (IT0000 STAT2 = 3) mit IT0001-ORGEH in dieser Menge
CLASS zcl_hr_teamabs_org DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_wegid_managed TYPE wegid VALUE 'SAP_MANG'.
    CONSTANTS gc_wegid_orgtree TYPE wegid VALUE 'ORGEH'.

    METHODS constructor
      IMPORTING
        iv_uname   TYPE syuname DEFAULT sy-uname
        iv_keydate TYPE dats DEFAULT sy-datum.

    "! Personalnummer des angemeldeten Benutzers (IT0105/0001)
    METHODS get_own_pernr
      RETURNING
        VALUE(rv_pernr) TYPE persno.

    "! Alle Org-Einheiten der eigenen Hierarchie (Wurzeln + Untereinheiten)
    METHODS get_org_units
      RETURNING
        VALUE(rt_org_units) TYPE zif_hr_teamabs_types=>tt_org_unit.

    "! Mitarbeiter der übergebenen Org-Einheiten.
    "! Org-Einheiten außerhalb der eigenen Hierarchie werden ignoriert,
    "! ist die Range leer, werden alle Mitarbeiter der Hierarchie geliefert.
    METHODS get_employees
      IMPORTING
        it_orgeh            TYPE zif_hr_teamabs_types=>tt_orgeh_range OPTIONAL
        iv_search           TYPE csequence OPTIONAL
      RETURNING
        VALUE(rt_employees) TYPE zif_hr_teamabs_types=>tt_employee.

    "! Prüft, ob eine Org-Einheit zur eigenen Hierarchie gehört
    METHODS is_org_unit_allowed
      IMPORTING
        iv_orgeh          TYPE orgeh
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_pa0001,
        pernr TYPE persno,
        ename TYPE emnam,
        orgeh TYPE orgeh,
        plans TYPE plans,
        werks TYPE persa,
        btrtl TYPE btrtl,
      END OF ty_pa0001,
      tt_pa0001 TYPE STANDARD TABLE OF ty_pa0001 WITH DEFAULT KEY,

      BEGIN OF ty_text,
        objid TYPE hrobjid,
        stext TYPE stext,
      END OF ty_text,
      tt_text TYPE SORTED TABLE OF ty_text WITH UNIQUE KEY objid.

    DATA mv_uname TYPE syuname.
    DATA mv_keydate TYPE dats.
    DATA mv_plvar TYPE plvar.
    DATA mv_pernr TYPE persno.
    DATA mv_pernr_read TYPE abap_bool.
    DATA mt_org_units TYPE zif_hr_teamabs_types=>tt_org_unit.
    DATA mv_org_read TYPE abap_bool.
    DATA mt_all_employees TYPE zif_hr_teamabs_types=>tt_employee.
    DATA mv_emp_read TYPE abap_bool.

    METHODS get_plvar
      RETURNING
        VALUE(rv_plvar) TYPE plvar.

    METHODS read_all_employees.

    METHODS read_position_texts
      IMPORTING
        it_pa0001      TYPE tt_pa0001
      RETURNING
        VALUE(rt_text) TYPE tt_text.

    METHODS add_subtree
      IMPORTING
        iv_root_orgeh TYPE orgeh.

ENDCLASS.



CLASS zcl_hr_teamabs_org IMPLEMENTATION.


  METHOD constructor.
    mv_uname = iv_uname.
    mv_keydate = iv_keydate.
  ENDMETHOD.


  METHOD get_own_pernr.
    IF mv_pernr_read = abap_false.
      SELECT pernr FROM pa0105 UP TO 1 ROWS
        INTO mv_pernr
        WHERE subty = '0001'
          AND usrid = mv_uname
          AND begda <= mv_keydate
          AND endda >= mv_keydate
          AND sprps = space
        ORDER BY PRIMARY KEY.
      ENDSELECT.
      mv_pernr_read = abap_true.
    ENDIF.
    rv_pernr = mv_pernr.
  ENDMETHOD.


  METHOD get_plvar.
    IF mv_plvar IS INITIAL.
      CALL FUNCTION 'RH_GET_ACTIVE_WF_PLVAR'
        IMPORTING
          act_plvar       = mv_plvar
        EXCEPTIONS
          no_active_plvar = 1
          OTHERS          = 2.
      IF sy-subrc <> 0.
        mv_plvar = '01'.
      ENDIF.
    ENDIF.
    rv_plvar = mv_plvar.
  ENDMETHOD.


  METHOD get_org_units.
    DATA lt_result TYPE STANDARD TABLE OF swhactor.
    DATA lt_objec TYPE STANDARD TABLE OF objec.
    DATA lt_struc TYPE STANDARD TABLE OF struc.
    DATA lv_objid TYPE realo.
    DATA lv_orgeh TYPE orgeh.
    FIELD-SYMBOLS <ls_objec> TYPE objec.
    FIELD-SYMBOLS <ls_org> TYPE zif_hr_teamabs_types=>ty_org_unit.

    IF mv_org_read = abap_true.
      rt_org_units = mt_org_units.
      RETURN.
    ENDIF.
    mv_org_read = abap_true.

    DATA(lv_pernr) = get_own_pernr( ).
    IF lv_pernr IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_plvar) = get_plvar( ).

    " Geführte Org-Einheiten (Leiterposition, A012)
    lv_objid = lv_pernr.
    CALL FUNCTION 'RH_STRUC_GET'
      EXPORTING
        act_otype       = 'P'
        act_objid       = lv_objid
        act_wegid       = gc_wegid_managed
        act_plvar       = lv_plvar
        act_begda       = mv_keydate
        act_endda       = mv_keydate
        authority_check = space
      TABLES
        result_tab      = lt_result
        result_objec    = lt_objec
        result_struc    = lt_struc
      EXCEPTIONS
        no_plvar_found  = 1
        no_entry_found  = 2
        OTHERS          = 3.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT lt_objec ASSIGNING <ls_objec> WHERE otype = 'O'.
      lv_orgeh = <ls_objec>-objid.
      add_subtree( lv_orgeh ).
    ENDLOOP.

    " Wurzeln markieren: Eltern-Einheit liegt nicht in der eigenen Hierarchie
    LOOP AT mt_org_units ASSIGNING <ls_org>.
      READ TABLE mt_org_units TRANSPORTING NO FIELDS WITH KEY orgeh = <ls_org>-parent.
      IF sy-subrc <> 0.
        CLEAR <ls_org>-parent.
        <ls_org>-is_root = abap_true.
        <ls_org>-hier_level = 1.
      ENDIF.
    ENDLOOP.

    " Mitarbeiterzahl je Org-Einheit (direkt zugeordnet)
    read_all_employees( ).
    LOOP AT mt_org_units ASSIGNING <ls_org>.
      LOOP AT mt_all_employees TRANSPORTING NO FIELDS WHERE orgeh = <ls_org>-orgeh.
        <ls_org>-emp_count = <ls_org>-emp_count + 1.
      ENDLOOP.
    ENDLOOP.

    rt_org_units = mt_org_units.
  ENDMETHOD.


  METHOD add_subtree.
    DATA lt_result TYPE STANDARD TABLE OF swhactor.
    DATA lt_objec TYPE STANDARD TABLE OF objec.
    DATA lt_struc TYPE STANDARD TABLE OF struc.
    DATA lv_objid TYPE realo.
    DATA ls_org TYPE zif_hr_teamabs_types=>ty_org_unit.
    FIELD-SYMBOLS <ls_struc> TYPE struc.
    FIELD-SYMBOLS <ls_parent> TYPE struc.
    FIELD-SYMBOLS <ls_objec> TYPE objec.
    FIELD-SYMBOLS <ls_known> TYPE zif_hr_teamabs_types=>ty_org_unit.

    " Schon über eine andere Wurzel erfasst?
    READ TABLE mt_org_units TRANSPORTING NO FIELDS WITH KEY orgeh = iv_root_orgeh.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    lv_objid = iv_root_orgeh.
    DATA(lv_plvar) = get_plvar( ).
    CALL FUNCTION 'RH_STRUC_GET'
      EXPORTING
        act_otype       = 'O'
        act_objid       = lv_objid
        act_wegid       = gc_wegid_orgtree
        act_plvar       = lv_plvar
        act_begda       = mv_keydate
        act_endda       = mv_keydate
        authority_check = space
      TABLES
        result_tab      = lt_result
        result_objec    = lt_objec
        result_struc    = lt_struc
      EXCEPTIONS
        no_plvar_found  = 1
        no_entry_found  = 2
        OTHERS          = 3.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT lt_struc ASSIGNING <ls_struc> WHERE otype = 'O'.
      CLEAR ls_org.
      ls_org-orgeh = <ls_struc>-objid.
      ls_org-hier_level = <ls_struc>-level.

      IF <ls_struc>-pup IS NOT INITIAL.
        READ TABLE lt_struc ASSIGNING <ls_parent> WITH KEY seqnr = <ls_struc>-pup.
        IF sy-subrc = 0.
          ls_org-parent = <ls_parent>-objid.
        ENDIF.
      ENDIF.

      READ TABLE mt_org_units ASSIGNING <ls_known> WITH KEY orgeh = ls_org-orgeh.
      IF sy-subrc = 0.
        " Einheit wurde vorher schon als eigene Wurzel gelesen -> nur Eltern nachtragen
        IF <ls_known>-parent IS INITIAL.
          <ls_known>-parent = ls_org-parent.
        ENDIF.
        CONTINUE.
      ENDIF.

      READ TABLE lt_objec ASSIGNING <ls_objec>
        WITH KEY otype = 'O' objid = <ls_struc>-objid.
      IF sy-subrc = 0.
        ls_org-short_text = <ls_objec>-short.
        ls_org-text = <ls_objec>-stext.
      ENDIF.

      APPEND ls_org TO mt_org_units.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_org_unit_allowed.
    get_org_units( ).
    READ TABLE mt_org_units TRANSPORTING NO FIELDS WITH KEY orgeh = iv_orgeh.
    rv_allowed = boolc( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD read_all_employees.
    DATA lt_pa0001 TYPE tt_pa0001.
    DATA lt_orgs TYPE zif_hr_teamabs_types=>tt_org_unit.
    DATA ls_emp TYPE zif_hr_teamabs_types=>ty_employee.
    FIELD-SYMBOLS <ls_pa0001> TYPE ty_pa0001.
    FIELD-SYMBOLS <ls_org> TYPE zif_hr_teamabs_types=>ty_org_unit.
    FIELD-SYMBOLS <ls_text> TYPE ty_text.

    IF mv_emp_read = abap_true.
      RETURN.
    ENDIF.
    mv_emp_read = abap_true.

    lt_orgs = mt_org_units.
    IF lt_orgs IS INITIAL.
      RETURN.
    ENDIF.

    " Aktive Mitarbeiter (IT0000 STAT2 = 3) mit Org-Zuordnung zum Stichtag
    SELECT p1~pernr p1~ename p1~orgeh p1~plans p1~werks p1~btrtl
      FROM pa0001 AS p1
      INNER JOIN pa0000 AS p0 ON p0~pernr = p1~pernr
      INTO TABLE lt_pa0001
      FOR ALL ENTRIES IN lt_orgs
      WHERE p1~orgeh = lt_orgs-orgeh
        AND p1~begda <= mv_keydate
        AND p1~endda >= mv_keydate
        AND p1~sprps = space
        AND p0~begda <= mv_keydate
        AND p0~endda >= mv_keydate
        AND p0~sprps = space
        AND p0~stat2 = '3'.

    DATA(lt_plans_text) = read_position_texts( lt_pa0001 ).

    LOOP AT lt_pa0001 ASSIGNING <ls_pa0001>.
      CLEAR ls_emp.
      MOVE-CORRESPONDING <ls_pa0001> TO ls_emp.
      READ TABLE mt_org_units ASSIGNING <ls_org> WITH KEY orgeh = <ls_pa0001>-orgeh.
      IF sy-subrc = 0.
        ls_emp-orgeh_text = <ls_org>-text.
      ENDIF.
      READ TABLE lt_plans_text ASSIGNING <ls_text> WITH TABLE KEY objid = <ls_pa0001>-plans.
      IF sy-subrc = 0.
        ls_emp-plans_text = <ls_text>-stext.
      ENDIF.
      APPEND ls_emp TO mt_all_employees.
    ENDLOOP.

    SORT mt_all_employees BY ename pernr.
  ENDMETHOD.


  METHOD read_position_texts.
    DATA lt_plans TYPE tt_pa0001.
    DATA lv_plvar TYPE plvar.

    lt_plans = it_pa0001.
    DELETE lt_plans WHERE plans IS INITIAL OR plans = '99999999'.
    SORT lt_plans BY plans.
    DELETE ADJACENT DUPLICATES FROM lt_plans COMPARING plans.
    IF lt_plans IS INITIAL.
      RETURN.
    ENDIF.

    lv_plvar = get_plvar( ).
    SELECT objid stext FROM hrp1000
      INTO TABLE rt_text
      FOR ALL ENTRIES IN lt_plans
      WHERE plvar = lv_plvar
        AND otype = 'S'
        AND objid = lt_plans-plans
        AND istat = '1'
        AND begda <= mv_keydate
        AND endda >= mv_keydate
        AND langu = sy-langu.
  ENDMETHOD.


  METHOD get_employees.
    FIELD-SYMBOLS <ls_emp> TYPE zif_hr_teamabs_types=>ty_employee.

    get_org_units( ).
    read_all_employees( ).

    LOOP AT mt_all_employees ASSIGNING <ls_emp>.
      IF it_orgeh IS NOT INITIAL AND <ls_emp>-orgeh NOT IN it_orgeh.
        CONTINUE.
      ENDIF.
      IF iv_search IS NOT INITIAL
         AND NOT ( <ls_emp>-ename CS iv_search OR <ls_emp>-pernr CS iv_search ).
        CONTINUE.
      ENDIF.
      APPEND <ls_emp> TO rt_employees.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
