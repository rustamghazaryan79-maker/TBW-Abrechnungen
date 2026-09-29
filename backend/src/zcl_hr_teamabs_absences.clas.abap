"! Liest geplante Abwesenheiten wie der Teamkalender in PTARQ:
"!  - gebuchte Abwesenheiten aus Infotyp 2001
"!  - Abwesenheitsanträge, die gestellt (SENT) oder genehmigt (APPROVED),
"!    aber noch nicht gebucht sind (PTREQ_HEADER / PTREQ_ITEMS / PTREQ_ATTABSDATA)
"!
"! Die Klasse prüft KEINE Berechtigung. Der Aufrufer (DPC) übergibt nur
"! Mitarbeiter aus der eigenen Org-Hierarchie.
"!
"! Datenschutz: Abwesenheitsarten, die in der TVARVC-Selektionsoption
"! ZHR_TEAMABS_AWART_MASK (Transaktion STVARV) stehen, werden nur als
"! "Abwesend" ohne Art ausgegeben – z. B. Krankheit oder Kur.
CLASS zcl_hr_teamabs_absences DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_tvarv_mask TYPE rvari_vnam VALUE 'ZHR_TEAMABS_AWART_MASK'.
    CONSTANTS gc_masked_text TYPE abwtxt VALUE 'Abwesend'.

    METHODS get_absences
      IMPORTING
        it_employees       TYPE zif_hr_teamabs_types=>tt_employee
        iv_begda           TYPE begda
        iv_endda           TYPE endda
        iv_with_requests   TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rt_absences) TYPE zif_hr_teamabs_types=>tt_absence.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_2001,
        pernr TYPE persno,
        subty TYPE subty,
        objps TYPE objps,
        sprps TYPE sprps,
        endda TYPE endda,
        begda TYPE begda,
        seqnr TYPE seqnr,
        awart TYPE awart,
        abwtg TYPE abwtg,
        stdaz TYPE abstd,
        beguz TYPE beguz,
        enduz TYPE enduz,
      END OF ty_2001,
      tt_2001 TYPE STANDARD TABLE OF ty_2001 WITH DEFAULT KEY,

      BEGIN OF ty_req_data,
        item_id      TYPE ptreq_attabsdata-item_id,
        operation    TYPE ptreq_attabsdata-operation,
        pernr        TYPE persno,
        subty        TYPE subty,
        begda        TYPE begda,
        endda        TYPE endda,
        begin_time   TYPE ptreq_attabsdata-begin_time,
        end_time     TYPE ptreq_attabsdata-end_time,
        abwtg        TYPE ptreq_attabsdata-abwtg,
        attabs_hours TYPE ptreq_attabsdata-attabs_hours,
        item_ins     TYPE ptreq_items-item_ins,
      END OF ty_req_data,
      tt_req_data TYPE STANDARD TABLE OF ty_req_data WITH DEFAULT KEY,

      BEGIN OF ty_item,
        item_list_id TYPE ptreq_items-item_list_id,
        item_ins     TYPE ptreq_items-item_ins,
      END OF ty_item,
      tt_item TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY,

      BEGIN OF ty_header,
        request_id   TYPE ptreq_header-request_id,
        version_no   TYPE ptreq_header-version_no,
        status       TYPE ptreq_header-status,
        item_list_id TYPE ptreq_header-item_list_id,
      END OF ty_header,
      tt_header TYPE STANDARD TABLE OF ty_header WITH DEFAULT KEY,

      BEGIN OF ty_moabw,
        werks TYPE persa,
        btrtl TYPE btrtl,
        moabw TYPE moabw,
      END OF ty_moabw,
      tt_moabw TYPE SORTED TABLE OF ty_moabw WITH UNIQUE KEY werks btrtl,

      BEGIN OF ty_awart_text,
        moabw TYPE moabw,
        awart TYPE awart,
        atext TYPE abwtxt,
      END OF ty_awart_text,
      tt_awart_text TYPE SORTED TABLE OF ty_awart_text WITH UNIQUE KEY moabw awart.

    DATA mt_moabw TYPE tt_moabw.
    DATA mt_awart_text TYPE tt_awart_text.

    METHODS read_infotype_2001
      IMPORTING
        it_employees TYPE zif_hr_teamabs_types=>tt_employee
        iv_begda     TYPE begda
        iv_endda     TYPE endda
      CHANGING
        ct_absences  TYPE zif_hr_teamabs_types=>tt_absence.

    METHODS read_leave_requests
      IMPORTING
        it_employees TYPE zif_hr_teamabs_types=>tt_employee
        iv_begda     TYPE begda
        iv_endda     TYPE endda
      CHANGING
        ct_absences  TYPE zif_hr_teamabs_types=>tt_absence.

    METHODS read_texts
      IMPORTING
        it_employees TYPE zif_hr_teamabs_types=>tt_employee.

    METHODS mask_sensitive_types
      CHANGING
        ct_absences TYPE zif_hr_teamabs_types=>tt_absence.

    METHODS get_awart_text
      IMPORTING
        is_employee    TYPE zif_hr_teamabs_types=>ty_employee
        iv_awart       TYPE awart
      RETURNING
        VALUE(rv_text) TYPE abwtxt.

ENDCLASS.



CLASS zcl_hr_teamabs_absences IMPLEMENTATION.


  METHOD get_absences.
    IF it_employees IS INITIAL OR iv_begda > iv_endda.
      RETURN.
    ENDIF.

    read_texts( it_employees ).
    read_infotype_2001(
      EXPORTING
        it_employees = it_employees
        iv_begda     = iv_begda
        iv_endda     = iv_endda
      CHANGING
        ct_absences  = rt_absences ).

    IF iv_with_requests = abap_true.
      read_leave_requests(
        EXPORTING
          it_employees = it_employees
          iv_begda     = iv_begda
          iv_endda     = iv_endda
        CHANGING
          ct_absences  = rt_absences ).
    ENDIF.

    mask_sensitive_types( CHANGING ct_absences = rt_absences ).

    SORT rt_absences BY ename pernr begda beguz.
  ENDMETHOD.


  METHOD mask_sensitive_types.
    DATA lt_mask TYPE RANGE OF awart.
    FIELD-SYMBOLS <ls_abs> TYPE zif_hr_teamabs_types=>ty_absence.

    SELECT sign opti AS option low high
      FROM tvarvc
      INTO CORRESPONDING FIELDS OF TABLE lt_mask
      WHERE name = gc_tvarv_mask
        AND type = 'S'.
    " Leere Range würde alles treffen
    IF lt_mask IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT ct_absences ASSIGNING <ls_abs> WHERE awart IN lt_mask.
      CLEAR <ls_abs>-awart.
      <ls_abs>-awart_text = gc_masked_text.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_infotype_2001.
    DATA lt_2001 TYPE tt_2001.
    DATA ls_abs TYPE zif_hr_teamabs_types=>ty_absence.
    FIELD-SYMBOLS <ls_2001> TYPE ty_2001.
    FIELD-SYMBOLS <ls_emp> TYPE zif_hr_teamabs_types=>ty_employee.

    SELECT pernr subty objps sprps endda begda seqnr awart abwtg stdaz beguz enduz
      FROM pa2001
      INTO TABLE lt_2001
      FOR ALL ENTRIES IN it_employees
      WHERE pernr = it_employees-pernr
        AND begda <= iv_endda
        AND endda >= iv_begda
        AND sprps = space.

    LOOP AT lt_2001 ASSIGNING <ls_2001>.
      READ TABLE it_employees ASSIGNING <ls_emp> WITH KEY pernr = <ls_2001>-pernr.
      CHECK sy-subrc = 0.

      CLEAR ls_abs.
      CONCATENATE zif_hr_teamabs_types=>gc_source-infotype
                  <ls_2001>-pernr <ls_2001>-subty <ls_2001>-objps
                  <ls_2001>-begda <ls_2001>-endda <ls_2001>-seqnr
             INTO ls_abs-absence_id.
      ls_abs-pernr      = <ls_2001>-pernr.
      ls_abs-ename      = <ls_emp>-ename.
      ls_abs-awart      = <ls_2001>-awart.
      ls_abs-awart_text = get_awart_text( is_employee = <ls_emp> iv_awart = <ls_2001>-awart ).
      ls_abs-begda      = <ls_2001>-begda.
      ls_abs-endda      = <ls_2001>-endda.
      ls_abs-beguz      = <ls_2001>-beguz.
      ls_abs-enduz      = <ls_2001>-enduz.
      ls_abs-abwtg      = <ls_2001>-abwtg.
      ls_abs-stdaz      = <ls_2001>-stdaz.
      ls_abs-status     = zif_hr_teamabs_types=>gc_status-posted.
      ls_abs-source     = zif_hr_teamabs_types=>gc_source-infotype.
      APPEND ls_abs TO ct_absences.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_leave_requests.
    DATA lt_req TYPE tt_req_data.
    DATA lt_items TYPE tt_item.
    DATA lt_hdr_hit TYPE tt_header.
    DATA lt_hdr_all TYPE tt_header.
    DATA ls_abs TYPE zif_hr_teamabs_types=>ty_absence.
    FIELD-SYMBOLS <ls_req> TYPE ty_req_data.
    FIELD-SYMBOLS <ls_item> TYPE ty_item.
    FIELD-SYMBOLS <ls_hdr> TYPE ty_header.
    FIELD-SYMBOLS <ls_emp> TYPE zif_hr_teamabs_types=>ty_employee.

    " 1) Antragspositionen (Abwesenheiten) der Mitarbeiter im Zeitraum
    SELECT item_id operation pernr subty begda endda begin_time end_time abwtg attabs_hours
      FROM ptreq_attabsdata
      INTO CORRESPONDING FIELDS OF TABLE lt_req
      FOR ALL ENTRIES IN it_employees
      WHERE pernr = it_employees-pernr
        AND infotype = '2001'
        AND begda <= iv_endda
        AND endda >= iv_begda.

    " Löschpositionen (Storno/Änderung einer bestehenden Abwesenheit) nicht anzeigen
    DELETE lt_req WHERE operation = 'DEL'.
    IF lt_req IS INITIAL.
      RETURN.
    ENDIF.

    " ITEM_ID ist die GUID im Zeichenformat, PTREQ_ITEMS-ITEM_INS ist RAW16
    LOOP AT lt_req ASSIGNING <ls_req>.
      <ls_req>-item_ins = <ls_req>-item_id.
    ENDLOOP.

    " 2) Zuordnung Position -> Positionsliste
    SELECT item_list_id item_ins
      FROM ptreq_items
      INTO TABLE lt_items
      FOR ALL ENTRIES IN lt_req
      WHERE item_ins = lt_req-item_ins.
    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " 3) Anträge, die diese Positionslisten verwenden ...
    SELECT request_id version_no status item_list_id
      FROM ptreq_header
      INTO TABLE lt_hdr_hit
      FOR ALL ENTRIES IN lt_items
      WHERE item_list_id = lt_items-item_list_id.
    IF lt_hdr_hit IS INITIAL.
      RETURN.
    ENDIF.

    " ... und davon jeweils die aktuelle (höchste) Version
    SELECT request_id version_no status item_list_id
      FROM ptreq_header
      INTO TABLE lt_hdr_all
      FOR ALL ENTRIES IN lt_hdr_hit
      WHERE request_id = lt_hdr_hit-request_id.
    SORT lt_hdr_all BY request_id ASCENDING version_no DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_hdr_all COMPARING request_id.

    " Gebuchte Anträge stehen schon in IT2001, abgelehnte/zurückgezogene interessieren nicht
    DELETE lt_hdr_all WHERE status <> zif_hr_teamabs_types=>gc_status-sent
                        AND status <> zif_hr_teamabs_types=>gc_status-approved.

    LOOP AT lt_hdr_all ASSIGNING <ls_hdr>.
      LOOP AT lt_items ASSIGNING <ls_item> WHERE item_list_id = <ls_hdr>-item_list_id.
        LOOP AT lt_req ASSIGNING <ls_req> WHERE item_ins = <ls_item>-item_ins.
          READ TABLE it_employees ASSIGNING <ls_emp> WITH KEY pernr = <ls_req>-pernr.
          CHECK sy-subrc = 0.

          CLEAR ls_abs.
          " Ein Antrag kann mehrere Positionen haben -> Ende der Positions-GUID anhängen
          CONCATENATE zif_hr_teamabs_types=>gc_source-request <ls_hdr>-request_id
                      <ls_req>-item_id+24(8)
                 INTO ls_abs-absence_id.
          ls_abs-pernr      = <ls_req>-pernr.
          ls_abs-ename      = <ls_emp>-ename.
          ls_abs-awart      = <ls_req>-subty.
          ls_abs-awart_text = get_awart_text( is_employee = <ls_emp> iv_awart = ls_abs-awart ).
          ls_abs-begda      = <ls_req>-begda.
          ls_abs-endda      = <ls_req>-endda.
          ls_abs-beguz      = <ls_req>-begin_time.
          ls_abs-enduz      = <ls_req>-end_time.
          ls_abs-abwtg      = <ls_req>-abwtg.
          ls_abs-stdaz      = <ls_req>-attabs_hours.
          ls_abs-status     = <ls_hdr>-status.
          ls_abs-source     = zif_hr_teamabs_types=>gc_source-request.
          APPEND ls_abs TO ct_absences.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.

    SORT ct_absences BY absence_id.
    DELETE ADJACENT DUPLICATES FROM ct_absences COMPARING absence_id.
  ENDMETHOD.


  METHOD read_texts.
    DATA lt_moabw TYPE STANDARD TABLE OF ty_moabw.
    DATA lt_text TYPE STANDARD TABLE OF ty_awart_text.

    IF mt_moabw IS NOT INITIAL.
      RETURN.
    ENDIF.

    " Personalteilbereichsgruppierung für Abwesenheitsarten
    SELECT werks btrtl moabw
      FROM t001p
      INTO TABLE lt_moabw
      FOR ALL ENTRIES IN it_employees
      WHERE werks = it_employees-werks
        AND btrtl = it_employees-btrtl.
    SORT lt_moabw BY werks btrtl.
    DELETE ADJACENT DUPLICATES FROM lt_moabw COMPARING werks btrtl.
    mt_moabw = lt_moabw.

    SELECT moabw awart atext
      FROM t554t
      INTO TABLE lt_text
      WHERE sprsl = sy-langu.
    SORT lt_text BY moabw awart.
    DELETE ADJACENT DUPLICATES FROM lt_text COMPARING moabw awart.
    mt_awart_text = lt_text.
  ENDMETHOD.


  METHOD get_awart_text.
    FIELD-SYMBOLS <ls_moabw> TYPE ty_moabw.
    FIELD-SYMBOLS <ls_text> TYPE ty_awart_text.

    READ TABLE mt_moabw ASSIGNING <ls_moabw>
      WITH TABLE KEY werks = is_employee-werks btrtl = is_employee-btrtl.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    READ TABLE mt_awart_text ASSIGNING <ls_text>
      WITH TABLE KEY moabw = <ls_moabw>-moabw awart = iv_awart.
    IF sy-subrc = 0.
      rv_text = <ls_text>-atext.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
