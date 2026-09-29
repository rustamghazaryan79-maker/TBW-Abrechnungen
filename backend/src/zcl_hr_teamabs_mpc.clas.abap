"! OData-Modell (V2) für ZHR_TEAMABS_SRV – ohne SEGW, komplett im Code definiert.
"!
"! Entitätsmengen:
"!   OrgUnits  – eigene Org-Hierarchie (Filter: keiner)
"!   Employees – Mitarbeiter (Filter: Orgeh eq …, Suche: search=…)
"!   Absences  – Abwesenheiten (Filter: Pernr eq …, EndDate ge …, BeginDate le …, Status eq …)
CLASS zcl_hr_teamabs_mpc DEFINITION
  PUBLIC
  INHERITING FROM /iwbep/cl_mgw_push_abs_model
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_namespace TYPE string VALUE 'ZHR_TEAMABS_SRV'.
    CONSTANTS gc_orgunit TYPE string VALUE 'OrgUnit'.
    CONSTANTS gc_employee TYPE string VALUE 'Employee'.
    CONSTANTS gc_absence TYPE string VALUE 'Absence'.
    CONSTANTS gc_set_orgunits TYPE string VALUE 'OrgUnits'.
    CONSTANTS gc_set_employees TYPE string VALUE 'Employees'.
    CONSTANTS gc_set_absences TYPE string VALUE 'Absences'.

    METHODS define REDEFINITION.
    METHODS get_last_modified REDEFINITION.

  PRIVATE SECTION.
    METHODS define_orgunit
      RAISING
        /iwbep/cx_mgw_med_exception.

    METHODS define_employee
      RAISING
        /iwbep/cx_mgw_med_exception.

    METHODS define_absence
      RAISING
        /iwbep/cx_mgw_med_exception.

    METHODS create_entity
      IMPORTING
        iv_name          TYPE string
      RETURNING
        VALUE(ro_entity) TYPE REF TO /iwbep/if_mgw_odata_entity_typ
      RAISING
        /iwbep/cx_mgw_med_exception.

    "! Nach den Properties aufrufen: Struktur binden und Entitätsmenge anlegen
    METHODS finish_entity
      IMPORTING
        io_entity     TYPE REF TO /iwbep/if_mgw_odata_entity_typ
        iv_set_name   TYPE string
        iv_structure  TYPE string
        iv_searchable TYPE abap_bool DEFAULT abap_false
      RAISING
        /iwbep/cx_mgw_med_exception.

    "! iv_edm: String | DateTime | Time | Decimal | Int32 | Boolean
    METHODS add_property
      IMPORTING
        io_entity     TYPE REF TO /iwbep/if_mgw_odata_entity_typ
        iv_name       TYPE string
        iv_abap_name  TYPE string
        iv_edm        TYPE string DEFAULT 'String'
        iv_length     TYPE i DEFAULT 0
        iv_decimals   TYPE i DEFAULT 0
        iv_label      TYPE string OPTIONAL
        iv_key        TYPE abap_bool DEFAULT abap_false
        iv_filterable TYPE abap_bool DEFAULT abap_false
      RAISING
        /iwbep/cx_mgw_med_exception.

ENDCLASS.



CLASS zcl_hr_teamabs_mpc IMPLEMENTATION.


  METHOD define.
    model->set_schema_namespace( CONV #( gc_namespace ) ).

    define_orgunit( ).
    define_employee( ).
    define_absence( ).
  ENDMETHOD.


  METHOD get_last_modified.
    " Bei Änderungen am Modell hochsetzen, damit der Metadaten-Cache erneuert wird
    CONSTANTS lc_model_changed TYPE timestamp VALUE '20260929120000'.

    rv_last_modified = super->get_last_modified( ).
    IF rv_last_modified < lc_model_changed.
      rv_last_modified = lc_model_changed.
    ENDIF.
  ENDMETHOD.


  METHOD define_orgunit.
    DATA(lo_entity) = create_entity( gc_orgunit ).

    add_property( io_entity = lo_entity iv_name = 'Orgeh' iv_abap_name = 'ORGEH'
                  iv_length = 8 iv_label = 'Org-Einheit' iv_key = abap_true ).
    add_property( io_entity = lo_entity iv_name = 'Parent' iv_abap_name = 'PARENT'
                  iv_length = 8 iv_label = 'Übergeordnete Org-Einheit' ).
    add_property( io_entity = lo_entity iv_name = 'ShortText' iv_abap_name = 'SHORT_TEXT'
                  iv_length = 12 iv_label = 'Kürzel' ).
    add_property( io_entity = lo_entity iv_name = 'Text' iv_abap_name = 'TEXT'
                  iv_length = 40 iv_label = 'Bezeichnung' ).
    add_property( io_entity = lo_entity iv_name = 'HierLevel' iv_abap_name = 'HIER_LEVEL'
                  iv_edm = 'Int32' iv_label = 'Ebene' ).
    add_property( io_entity = lo_entity iv_name = 'IsRoot' iv_abap_name = 'IS_ROOT'
                  iv_edm = 'Boolean' iv_label = 'Wurzel' ).
    add_property( io_entity = lo_entity iv_name = 'EmpCount' iv_abap_name = 'EMP_COUNT'
                  iv_edm = 'Int32' iv_label = 'Mitarbeiter' ).

    finish_entity(
      io_entity     = lo_entity
      iv_set_name   = gc_set_orgunits
      iv_structure  = 'ZIF_HR_TEAMABS_TYPES=>TY_ORG_UNIT' ).
  ENDMETHOD.


  METHOD define_employee.
    DATA(lo_entity) = create_entity( gc_employee ).

    add_property( io_entity = lo_entity iv_name = 'Pernr' iv_abap_name = 'PERNR'
                  iv_length = 8 iv_label = 'Personalnummer' iv_key = abap_true iv_filterable = abap_true ).
    add_property( io_entity = lo_entity iv_name = 'Name' iv_abap_name = 'ENAME'
                  iv_length = 40 iv_label = 'Name' ).
    add_property( io_entity = lo_entity iv_name = 'Orgeh' iv_abap_name = 'ORGEH'
                  iv_length = 8 iv_label = 'Org-Einheit' iv_filterable = abap_true ).
    add_property( io_entity = lo_entity iv_name = 'OrgehText' iv_abap_name = 'ORGEH_TEXT'
                  iv_length = 40 iv_label = 'Org-Einheit (Text)' ).
    add_property( io_entity = lo_entity iv_name = 'Plans' iv_abap_name = 'PLANS'
                  iv_length = 8 iv_label = 'Planstelle' ).
    add_property( io_entity = lo_entity iv_name = 'PlansText' iv_abap_name = 'PLANS_TEXT'
                  iv_length = 40 iv_label = 'Planstelle (Text)' ).
    add_property( io_entity = lo_entity iv_name = 'Werks' iv_abap_name = 'WERKS'
                  iv_length = 4 iv_label = 'Personalbereich' ).
    add_property( io_entity = lo_entity iv_name = 'Btrtl' iv_abap_name = 'BTRTL'
                  iv_length = 4 iv_label = 'Personalteilbereich' ).

    finish_entity(
      io_entity     = lo_entity
      iv_set_name   = gc_set_employees
      iv_structure  = 'ZIF_HR_TEAMABS_TYPES=>TY_EMPLOYEE'
      iv_searchable = abap_true ).
  ENDMETHOD.


  METHOD define_absence.
    DATA(lo_entity) = create_entity( gc_absence ).

    add_property( io_entity = lo_entity iv_name = 'AbsenceId' iv_abap_name = 'ABSENCE_ID'
                  iv_length = 50 iv_label = 'ID' iv_key = abap_true ).
    add_property( io_entity = lo_entity iv_name = 'Pernr' iv_abap_name = 'PERNR'
                  iv_length = 8 iv_label = 'Personalnummer' iv_filterable = abap_true ).
    add_property( io_entity = lo_entity iv_name = 'Name' iv_abap_name = 'ENAME'
                  iv_length = 40 iv_label = 'Name' ).
    add_property( io_entity = lo_entity iv_name = 'AbsenceType' iv_abap_name = 'AWART'
                  iv_length = 4 iv_label = 'Abwesenheitsart' ).
    add_property( io_entity = lo_entity iv_name = 'AbsenceTypeText' iv_abap_name = 'AWART_TEXT'
                  iv_length = 25 iv_label = 'Abwesenheitsart (Text)' ).
    add_property( io_entity = lo_entity iv_name = 'BeginDate' iv_abap_name = 'BEGDA'
                  iv_edm = 'DateTime' iv_label = 'Beginn' iv_filterable = abap_true ).
    add_property( io_entity = lo_entity iv_name = 'EndDate' iv_abap_name = 'ENDDA'
                  iv_edm = 'DateTime' iv_label = 'Ende' iv_filterable = abap_true ).
    add_property( io_entity = lo_entity iv_name = 'BeginTime' iv_abap_name = 'BEGUZ'
                  iv_edm = 'Time' iv_label = 'Beginnzeit' ).
    add_property( io_entity = lo_entity iv_name = 'EndTime' iv_abap_name = 'ENDUZ'
                  iv_edm = 'Time' iv_label = 'Endezeit' ).
    add_property( io_entity = lo_entity iv_name = 'Days' iv_abap_name = 'ABWTG'
                  iv_edm = 'Decimal' iv_length = 6 iv_decimals = 2 iv_label = 'Tage' ).
    add_property( io_entity = lo_entity iv_name = 'Hours' iv_abap_name = 'STDAZ'
                  iv_edm = 'Decimal' iv_length = 7 iv_decimals = 2 iv_label = 'Stunden' ).
    add_property( io_entity = lo_entity iv_name = 'Status' iv_abap_name = 'STATUS'
                  iv_length = 12 iv_label = 'Status' iv_filterable = abap_true ).
    add_property( io_entity = lo_entity iv_name = 'Source' iv_abap_name = 'SOURCE'
                  iv_length = 4 iv_label = 'Herkunft' ).

    finish_entity(
      io_entity     = lo_entity
      iv_set_name   = gc_set_absences
      iv_structure  = 'ZIF_HR_TEAMABS_TYPES=>TY_ABSENCE' ).
  ENDMETHOD.


  METHOD create_entity.
    ro_entity = model->create_entity_type(
      iv_entity_type_name = CONV #( iv_name )
      iv_def_entity_set   = abap_false ).
  ENDMETHOD.


  METHOD finish_entity.
    io_entity->bind_structure(
      iv_structure_name   = CONV #( iv_structure )
      iv_bind_conversions = abap_true ).

    DATA(lo_set) = io_entity->create_entity_set( CONV #( iv_set_name ) ).
    lo_set->set_creatable( abap_false ).
    lo_set->set_updatable( abap_false ).
    lo_set->set_deletable( abap_false ).
    lo_set->set_pageable( abap_true ).
    lo_set->set_addressable( abap_true ).
    lo_set->set_has_ftxt_search( iv_searchable ).
  ENDMETHOD.


  METHOD add_property.
    DATA(lo_property) = io_entity->create_property(
      iv_property_name  = CONV #( iv_name )
      iv_abap_fieldname = CONV #( iv_abap_name ) ).

    CASE iv_edm.
      WHEN 'DateTime'.
        lo_property->set_type_edm_datetime( ).
        lo_property->set_precison( iv_precision = 7 ).
        lo_property->/iwbep/if_mgw_odata_annotatabl~create_annotation( 'sap' )->add(
          iv_key = 'display-format' iv_value = 'Date' ).
      WHEN 'Time'.
        lo_property->set_type_edm_time( ).
      WHEN 'Decimal'.
        lo_property->set_type_edm_decimal( ).
        lo_property->set_precison( iv_precision = CONV #( iv_decimals ) ).
        lo_property->set_maxlength( iv_max_length = CONV #( iv_length ) ).
      WHEN 'Int32'.
        lo_property->set_type_edm_int32( ).
      WHEN 'Boolean'.
        lo_property->set_type_edm_boolean( ).
      WHEN OTHERS.
        lo_property->set_type_edm_string( ).
        IF iv_length > 0.
          lo_property->set_maxlength( iv_max_length = CONV #( iv_length ) ).
        ENDIF.
    ENDCASE.

    IF iv_key = abap_true.
      lo_property->set_is_key( ).
    ENDIF.
    lo_property->set_creatable( abap_false ).
    lo_property->set_updatable( abap_false ).
    lo_property->set_sortable( abap_true ).
    lo_property->set_nullable( abap_false ).
    lo_property->set_filterable( iv_filterable ).

    IF iv_label IS NOT INITIAL.
      lo_property->/iwbep/if_mgw_odata_annotatabl~create_annotation( 'sap' )->add(
        iv_key = 'label' iv_value = CONV #( iv_label ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
