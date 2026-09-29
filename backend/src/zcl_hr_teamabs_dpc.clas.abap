"! Datenprovider für ZHR_TEAMABS_SRV.
"!
"! Wichtig: Der Service vertraut den Filtern des Frontends NICHT. Jede Anfrage
"! wird auf die eigene Org-Hierarchie des angemeldeten Benutzers eingeschränkt
"! (siehe ZCL_HR_TEAMABS_ORG). Wer keine Org-Einheit leitet, sieht nichts.
CLASS zcl_hr_teamabs_dpc DEFINITION
  PUBLIC
  INHERITING FROM /iwbep/cl_mgw_abs_data
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS /iwbep/if_mgw_appl_srv_runtime~get_entityset REDEFINITION.
    METHODS /iwbep/if_mgw_appl_srv_runtime~get_entity REDEFINITION.

  PRIVATE SECTION.
    "! Maximale Länge des Auswertungszeitraums in Tagen
    CONSTANTS gc_max_period_days TYPE i VALUE 400.

    DATA mo_org TYPE REF TO zcl_hr_teamabs_org.

    METHODS org
      RETURNING
        VALUE(ro_org) TYPE REF TO zcl_hr_teamabs_org.

    METHODS get_org_units
      IMPORTING
        io_request   TYPE REF TO /iwbep/if_mgw_req_entityset
        is_paging    TYPE /iwbep/s_mgw_paging
      EXPORTING
        er_entityset TYPE REF TO data
        es_context   TYPE /iwbep/if_mgw_appl_srv_runtime=>ty_s_mgw_response_context
      RAISING
        /iwbep/cx_mgw_busi_exception
        /iwbep/cx_mgw_tech_exception.

    METHODS get_employees
      IMPORTING
        io_request   TYPE REF TO /iwbep/if_mgw_req_entityset
        is_paging    TYPE /iwbep/s_mgw_paging
        iv_search    TYPE string
      EXPORTING
        er_entityset TYPE REF TO data
        es_context   TYPE /iwbep/if_mgw_appl_srv_runtime=>ty_s_mgw_response_context
      RAISING
        /iwbep/cx_mgw_busi_exception
        /iwbep/cx_mgw_tech_exception.

    METHODS get_absences
      IMPORTING
        io_request   TYPE REF TO /iwbep/if_mgw_req_entityset
        is_paging    TYPE /iwbep/s_mgw_paging
      EXPORTING
        er_entityset TYPE REF TO data
        es_context   TYPE /iwbep/if_mgw_appl_srv_runtime=>ty_s_mgw_response_context
      RAISING
        /iwbep/cx_mgw_busi_exception
        /iwbep/cx_mgw_tech_exception.

    METHODS get_select_options
      IMPORTING
        io_request               TYPE REF TO /iwbep/if_mgw_req_entityset
        iv_property              TYPE string
      RETURNING
        VALUE(rt_select_options) TYPE /iwbep/t_cod_select_options
      RAISING
        /iwbep/cx_mgw_tech_exception.

    "! Wandelt einen Filterwert (20260101, 2026-01-01T00:00:00, …) in ein Datum
    METHODS to_date
      IMPORTING
        iv_value       TYPE any
      RETURNING
        VALUE(rv_date) TYPE dats.

    METHODS raise_error
      IMPORTING
        iv_text TYPE string
      RAISING
        /iwbep/cx_mgw_busi_exception.

ENDCLASS.



CLASS zcl_hr_teamabs_dpc IMPLEMENTATION.


  METHOD org.
    IF mo_org IS NOT BOUND.
      mo_org = NEW zcl_hr_teamabs_org( iv_uname = sy-uname iv_keydate = sy-datum ).
    ENDIF.
    ro_org = mo_org.
  ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~get_entityset.
    CASE iv_entity_set_name.
      WHEN zcl_hr_teamabs_mpc=>gc_set_orgunits.
        get_org_units(
          EXPORTING
            io_request   = io_tech_request_context
            is_paging    = is_paging
          IMPORTING
            er_entityset = er_entityset
            es_context   = es_response_context ).

      WHEN zcl_hr_teamabs_mpc=>gc_set_employees.
        get_employees(
          EXPORTING
            io_request   = io_tech_request_context
            is_paging    = is_paging
            iv_search    = iv_search_string
          IMPORTING
            er_entityset = er_entityset
            es_context   = es_response_context ).

      WHEN zcl_hr_teamabs_mpc=>gc_set_absences.
        get_absences(
          EXPORTING
            io_request   = io_tech_request_context
            is_paging    = is_paging
          IMPORTING
            er_entityset = er_entityset
            es_context   = es_response_context ).

      WHEN OTHERS.
        super->/iwbep/if_mgw_appl_srv_runtime~get_entityset(
          EXPORTING
            iv_entity_name           = iv_entity_name
            iv_entity_set_name       = iv_entity_set_name
            iv_source_name           = iv_source_name
            it_filter_select_options = it_filter_select_options
            it_order                 = it_order
            is_paging                = is_paging
            it_navigation_path       = it_navigation_path
            it_key_tab               = it_key_tab
            iv_filter_string         = iv_filter_string
            iv_search_string         = iv_search_string
            io_tech_request_context  = io_tech_request_context
          IMPORTING
            er_entityset             = er_entityset
            es_response_context      = es_response_context ).
    ENDCASE.
  ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~get_entity.
    DATA lv_orgeh TYPE orgeh.
    DATA lv_pernr TYPE persno.

    DATA(lt_keys) = io_tech_request_context->get_keys( ).

    CASE iv_entity_set_name.
      WHEN zcl_hr_teamabs_mpc=>gc_set_orgunits.
        READ TABLE lt_keys INTO DATA(ls_org_key) WITH KEY name = 'ORGEH'.
        lv_orgeh = ls_org_key-value.
        DATA(lt_org) = org( )->get_org_units( ).
        READ TABLE lt_org INTO DATA(ls_org) WITH KEY orgeh = lv_orgeh.
        IF sy-subrc <> 0.
          raise_error( |Org-Einheit { lv_orgeh } gehört nicht zu Ihrer Org-Hierarchie| ).
        ENDIF.
        copy_data_to_ref( EXPORTING is_data = ls_org CHANGING cr_data = er_entity ).

      WHEN zcl_hr_teamabs_mpc=>gc_set_employees.
        READ TABLE lt_keys INTO DATA(ls_emp_key) WITH KEY name = 'PERNR'.
        lv_pernr = ls_emp_key-value.
        DATA(lt_emp) = org( )->get_employees( ).
        READ TABLE lt_emp INTO DATA(ls_emp) WITH KEY pernr = lv_pernr.
        IF sy-subrc <> 0.
          raise_error( |Mitarbeiter { lv_pernr } gehört nicht zu Ihrer Org-Hierarchie| ).
        ENDIF.
        copy_data_to_ref( EXPORTING is_data = ls_emp CHANGING cr_data = er_entity ).

      WHEN OTHERS.
        super->/iwbep/if_mgw_appl_srv_runtime~get_entity(
          EXPORTING
            iv_entity_name          = iv_entity_name
            iv_entity_set_name      = iv_entity_set_name
            iv_source_name          = iv_source_name
            it_key_tab              = it_key_tab
            it_navigation_path      = it_navigation_path
            io_tech_request_context = io_tech_request_context
          IMPORTING
            er_entity               = er_entity
            es_response_context     = es_response_context ).
    ENDCASE.
  ENDMETHOD.


  METHOD get_org_units.
    DATA(lt_org) = org( )->get_org_units( ).

    IF io_request->has_inlinecount( ) = abap_true.
      es_context-inlinecount = lines( lt_org ).
    ENDIF.
    /iwbep/cl_mgw_data_util=>paging( EXPORTING is_paging = is_paging CHANGING ct_data = lt_org ).

    copy_data_to_ref( EXPORTING is_data = lt_org CHANGING cr_data = er_entityset ).
  ENDMETHOD.


  METHOD get_employees.
    DATA lt_orgeh TYPE zif_hr_teamabs_types=>tt_orgeh_range.
    DATA ls_orgeh LIKE LINE OF lt_orgeh.
    DATA lt_pernr TYPE zif_hr_teamabs_types=>tt_pernr_range.
    DATA ls_pernr LIKE LINE OF lt_pernr.

    " Filter Orgeh: nur Org-Einheiten der eigenen Hierarchie zulassen
    DATA(lt_so_orgeh) = get_select_options( io_request = io_request iv_property = 'ORGEH' ).
    LOOP AT lt_so_orgeh INTO DATA(ls_so).
      CLEAR ls_orgeh.
      ls_orgeh-sign   = ls_so-sign.
      ls_orgeh-option = ls_so-option.
      ls_orgeh-low    = ls_so-low.
      ls_orgeh-high   = ls_so-high.
      IF ls_orgeh-option = 'EQ' AND org( )->is_org_unit_allowed( ls_orgeh-low ) = abap_false.
        raise_error( |Org-Einheit { ls_orgeh-low } gehört nicht zu Ihrer Org-Hierarchie| ).
      ENDIF.
      APPEND ls_orgeh TO lt_orgeh.
    ENDLOOP.

    DATA(lt_so_pernr) = get_select_options( io_request = io_request iv_property = 'PERNR' ).
    LOOP AT lt_so_pernr INTO ls_so.
      CLEAR ls_pernr.
      ls_pernr-sign   = ls_so-sign.
      ls_pernr-option = ls_so-option.
      ls_pernr-low    = ls_so-low.
      ls_pernr-high   = ls_so-high.
      APPEND ls_pernr TO lt_pernr.
    ENDLOOP.

    DATA(lt_emp) = org( )->get_employees( it_orgeh = lt_orgeh iv_search = iv_search ).
    IF lt_pernr IS NOT INITIAL.
      DELETE lt_emp WHERE pernr NOT IN lt_pernr.
    ENDIF.

    IF io_request->has_inlinecount( ) = abap_true.
      es_context-inlinecount = lines( lt_emp ).
    ENDIF.
    /iwbep/cl_mgw_data_util=>paging( EXPORTING is_paging = is_paging CHANGING ct_data = lt_emp ).

    copy_data_to_ref( EXPORTING is_data = lt_emp CHANGING cr_data = er_entityset ).
  ENDMETHOD.


  METHOD get_absences.
    DATA lt_pernr TYPE zif_hr_teamabs_types=>tt_pernr_range.
    DATA ls_pernr LIKE LINE OF lt_pernr.
    DATA lt_status TYPE RANGE OF char12.
    DATA ls_status LIKE LINE OF lt_status.
    DATA lv_begda TYPE begda.
    DATA lv_endda TYPE endda.

    " Zeitraum: EndDate ge <von> and BeginDate le <bis> (Überschneidung)
    DATA(lt_so_endda) = get_select_options( io_request = io_request iv_property = 'ENDDA' ).
    LOOP AT lt_so_endda INTO DATA(ls_so).
      CASE ls_so-option.
        WHEN 'GE' OR 'GT' OR 'EQ'.
          lv_begda = to_date( ls_so-low ).
        WHEN 'BT'.
          lv_begda = to_date( ls_so-low ).
      ENDCASE.
    ENDLOOP.
    DATA(lt_so_begda) = get_select_options( io_request = io_request iv_property = 'BEGDA' ).
    LOOP AT lt_so_begda INTO ls_so.
      CASE ls_so-option.
        WHEN 'LE' OR 'LT' OR 'EQ'.
          lv_endda = to_date( ls_so-low ).
        WHEN 'BT'.
          lv_endda = to_date( ls_so-high ).
      ENDCASE.
    ENDLOOP.

    " Standard wie im Teamkalender: aktueller Monat
    IF lv_begda IS INITIAL.
      lv_begda = sy-datum.
      lv_begda+6(2) = '01'.
    ENDIF.
    IF lv_endda IS INITIAL.
      lv_endda = lv_begda + 31.
    ENDIF.
    IF lv_endda < lv_begda.
      raise_error( |Das Ende des Zeitraums liegt vor dem Beginn| ).
    ENDIF.
    IF lv_endda - lv_begda > gc_max_period_days.
      raise_error( |Der Zeitraum darf höchstens { gc_max_period_days } Tage umfassen| ).
    ENDIF.

    DATA(lt_so_pernr) = get_select_options( io_request = io_request iv_property = 'PERNR' ).
    LOOP AT lt_so_pernr INTO ls_so.
      CLEAR ls_pernr.
      ls_pernr-sign   = ls_so-sign.
      ls_pernr-option = ls_so-option.
      ls_pernr-low    = ls_so-low.
      ls_pernr-high   = ls_so-high.
      APPEND ls_pernr TO lt_pernr.
    ENDLOOP.

    DATA(lt_so_status) = get_select_options( io_request = io_request iv_property = 'STATUS' ).
    LOOP AT lt_so_status INTO ls_so.
      CLEAR ls_status.
      ls_status-sign   = ls_so-sign.
      ls_status-option = ls_so-option.
      ls_status-low    = ls_so-low.
      ls_status-high   = ls_so-high.
      APPEND ls_status TO lt_status.
    ENDLOOP.

    " Nur Mitarbeiter der eigenen Hierarchie – egal, was der Client schickt
    DATA(lt_emp) = org( )->get_employees( ).
    IF lt_pernr IS NOT INITIAL.
      DELETE lt_emp WHERE pernr NOT IN lt_pernr.
    ENDIF.

    DATA(lt_abs) = NEW zcl_hr_teamabs_absences( )->get_absences(
      it_employees = lt_emp
      iv_begda     = lv_begda
      iv_endda     = lv_endda ).

    IF lt_status IS NOT INITIAL.
      DELETE lt_abs WHERE status NOT IN lt_status.
    ENDIF.

    IF io_request->has_inlinecount( ) = abap_true.
      es_context-inlinecount = lines( lt_abs ).
    ENDIF.
    /iwbep/cl_mgw_data_util=>paging( EXPORTING is_paging = is_paging CHANGING ct_data = lt_abs ).

    copy_data_to_ref( EXPORTING is_data = lt_abs CHANGING cr_data = er_entityset ).
  ENDMETHOD.


  METHOD get_select_options.
    DATA(lt_filter) = io_request->get_filter( )->get_filter_select_options( ).
    READ TABLE lt_filter INTO DATA(ls_filter) WITH KEY property = iv_property.
    IF sy-subrc = 0.
      rt_select_options = ls_filter-select_options.
    ENDIF.
  ENDMETHOD.


  METHOD to_date.
    DATA lv_digits TYPE string.

    lv_digits = iv_value.
    REPLACE ALL OCCURRENCES OF REGEX '[^0-9]' IN lv_digits WITH ''.
    IF strlen( lv_digits ) >= 8.
      rv_date = lv_digits(8).
    ENDIF.
  ENDMETHOD.


  METHOD raise_error.
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING
        textid  = /iwbep/cx_mgw_busi_exception=>business_error
        message = CONV #( iv_text ).
  ENDMETHOD.

ENDCLASS.
