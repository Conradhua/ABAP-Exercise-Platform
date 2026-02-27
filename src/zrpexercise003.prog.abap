*&---------------------------------------------------------------------*
*& Report zrpexercise003
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zrpexercise003.



CLASS lcl_solutions DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS start IMPORTING ex_id TYPE ze_ex_id_cr.
    METHODS handle_user_command IMPORTING command TYPE sy-ucomm.
    METHODS on_alv_hotspot_click FOR EVENT hotspot_click OF cl_gui_alv_grid
      IMPORTING e_row_id.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_solution_out,
             ex_id              TYPE ztex_submission-ex_id,
             user_id            TYPE ztex_submission-user_id,
             name_text          TYPE ztex_submission-name_text,
             status             TYPE ztex_submission-status,
             first_success_date TYPE ztex_submission-first_success_date,
             first_success_time TYPE ztex_submission-first_success_time,
             last_date          TYPE ztex_submission-last_date,
             last_time          TYPE ztex_submission-last_time,
           END OF ty_solution_out.
    DATA solution_outs TYPE STANDARD TABLE OF ty_solution_out WITH EMPTY KEY.
    DATA exercise_id TYPE ze_ex_desc_cr.


    DATA docking_container TYPE REF TO cl_gui_docking_container.
    DATA splitter_main TYPE REF TO cl_gui_splitter_container.
    DATA container_left TYPE REF TO cl_gui_container.
    DATA container_right TYPE REF TO cl_gui_container.
    DATA alv_grid TYPE REF TO cl_gui_alv_grid.
    DATA code_editor TYPE REF TO cl_gui_abapedit.

    METHODS initial_layout.
    METHODS render_list_view.
    METHODS render_editor_view.
    METHODS load_solution.
    METHODS display_code.
    METHODS exclude_button.

ENDCLASS.

CLASS lcl_solutions IMPLEMENTATION.

  METHOD display_code.

  ENDMETHOD.

  METHOD exclude_button.
    DATA exclude_buttons TYPE TABLE OF sy-ucomm.

    " Always exclude standard print/execute
    exclude_buttons = VALUE #( ( 'ONLI' )
                               ( 'PRIN' )
                               ( 'SPOS' ) ).

    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING
        p_status  = '%_00'
        p_program = sy-repid
      TABLES
        p_exclude = exclude_buttons.

  ENDMETHOD.

  METHOD handle_user_command.

  ENDMETHOD.

  METHOD initial_layout.
    CHECK docking_container IS NOT BOUND.

    docking_container = NEW #( side = cl_gui_docking_container=>dock_at_bottom
                               extension = 9999 ).

    splitter_main = NEW #( parent = docking_container
                           rows = 1
                           columns = 2 ).

    container_left = splitter_main->get_container(
                       row    =  1
                       column = 1
                     ).
    container_right = splitter_main->get_container(
                       row    =  1
                       column = 2
                     ).

  ENDMETHOD.

  METHOD load_solution.

    CHECK me->exercise_id IS NOT INITIAL.

    SELECT *
      FROM ztex_submission
      WHERE ex_id = @me->exercise_id
        AND status = 'S'
      ORDER BY first_success_date, first_success_time
      INTO CORRESPONDING FIELDS OF TABLE @me->solution_outs.

  ENDMETHOD.

  METHOD on_alv_hotspot_click.

    CHECK e_row_id IS NOT INITIAL.

    DATA(uname) = VALUE #( me->solution_outs[ e_row_id ]-user_id OPTIONAL ).

    SELECT SINGLE
           user_code
      FROM ztex_submission
      WHERE ex_id = @me->exercise_id
        AND user_id = @uname
      INTO @DATA(user_code).

    DATA(code_lines) = VALUE string_table( ).
    IF user_code IS NOT INITIAL.
      SPLIT user_code AT cl_abap_char_utilities=>cr_lf INTO TABLE code_lines.
    ENDIF.

    IF code_editor IS NOT BOUND.
      render_editor_view( ).
    ENDIF.

    me->code_editor->set_text( table = code_lines ).

  ENDMETHOD.

  METHOD render_editor_view.

    IF code_editor IS NOT BOUND.
      code_editor = NEW #( parent = container_right ).
      code_editor->set_statusbar_mode( 1 ).
      code_editor->set_toolbar_mode( 0 ).
      code_editor->set_readonly_mode( 1 ).
    ENDIF.

    DATA(code_lines) = VALUE string_table( ).
    APPEND |" Please click Exercise ID to display ABAP Code.| TO code_lines.
    code_editor->set_text( table = code_lines ).

  ENDMETHOD.

  METHOD render_list_view.
    IF alv_grid IS NOT BOUND.
      alv_grid = NEW #( i_parent = container_left ).
      SET HANDLER on_alv_hotspot_click FOR alv_grid.
    ENDIF.

    load_solution( ).

    DATA(field_catalog) = VALUE lvc_t_fcat(
        ( fieldname = 'EX_ID' coltext = 'Exercise' outputlen = 10 style = cl_gui_alv_grid=>mc_style_hotspot )
        ( fieldname = 'USER_ID' coltext = 'User' outputlen = 12 )
        ( fieldname = 'NAME_TEXT' coltext = 'Name' outputlen = 30 )
        ( fieldname = 'FIRST_SUCCESS_DATE' coltext = 'First Date' outputlen = 10 )
        ( fieldname = 'FIRST_SUCCESS_TIME' coltext = 'First Time' outputlen = 8 )
        ( fieldname = 'LAST_DATE' coltext = 'Last Date' outputlen = 10 )
        ( fieldname = 'LAST_TIME' coltext = 'Last Time' outputlen = 8 ) ).

    alv_grid->set_table_for_first_display( EXPORTING is_layout       = VALUE #( no_toolbar = abap_true
                                                                                cwidth_opt = 'A'
                                                                                zebra      = abap_true )
                                           CHANGING  it_outtab       = me->solution_outs
                                                     it_fieldcatalog = field_catalog ).
  ENDMETHOD.

  METHOD start.
    me->exercise_id = ex_id.

    exclude_button( ).

    initial_layout( ).
    render_list_view( ).
    render_editor_view( ).

  ENDMETHOD.

ENDCLASS.

DATA solutions TYPE REF TO lcl_solutions.

PARAMETERS p_dummy TYPE c.

INITIALIZATION.

  DATA ex_id TYPE ztex_desc-ex_id.

  IMPORT ex_id = ex_id FROM MEMORY ID 'EXERCISE_ID'.

  solutions = NEW #( ).
  solutions->start( ex_id ).
