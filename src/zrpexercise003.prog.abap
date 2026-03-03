*&---------------------------------------------------------------------*
*& Report zrpexercise003
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zrpexercise003.
TABLES sscrfields.



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

    TYPES: BEGIN OF ty_exercise_out,
             ex_id      TYPE ztex_desc-ex_id,
             title      TYPE ztex_desc-title,
             short_desc TYPE ztex_desc-short_desc,
           END OF ty_exercise_out.
    DATA exercise_outs TYPE STANDARD TABLE OF ty_exercise_out WITH EMPTY KEY.


    DATA docking_container TYPE REF TO cl_gui_docking_container.
    DATA splitter_main TYPE REF TO cl_gui_splitter_container.
    DATA container_left TYPE REF TO cl_gui_container.
    DATA container_right TYPE REF TO cl_gui_container.
    DATA alv_grid TYPE REF TO cl_gui_alv_grid.
    DATA code_editor TYPE REF TO cl_gui_abapedit.
    DATA current_mode TYPE c LENGTH 1 VALUE 'V'. " V: view, A: Add.
    DATA current_add_ex_id TYPE ztex_desc-ex_id.

    METHODS initial_layout.
    METHODS render_list_view.
    METHODS render_editor_view.
    METHODS load_solution.
    METHODS display_code.
    METHODS update_button.
    METHODS load_exercises.
    METHODS save_solution.

ENDCLASS.

CLASS lcl_solutions IMPLEMENTATION.

  METHOD display_code.

  ENDMETHOD.

  METHOD update_button.
    DATA exclude_buttons TYPE TABLE OF sy-ucomm.

    " Always exclude standard print/execute
    exclude_buttons = VALUE #( ( 'ONLI' )
                               ( 'PRIN' )
                               ( 'SPOS' ) ).
    SELECT SINGLE
           @abap_true
      FROM trdir
      WHERE name = @sy-repid
        AND cnam = @sy-uname
      INTO @DATA(report_exists).
    IF report_exists = abap_true.
      IF current_mode = 'V'.
        " View Mode: Hide Save (FC02)
        APPEND 'FC02' TO exclude_buttons.
        sscrfields-functxt_01 = 'Add Solution'.
      ELSE.
        " Add Mode: Show Save
        sscrfields-functxt_01 = 'View Solutions'.
        sscrfields-functxt_02 = 'Save Solution'.
      ENDIF.
    ELSE.
      APPEND 'FC01' TO exclude_buttons.
      APPEND 'FC02' TO exclude_buttons.
    ENDIF.

    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING
        p_status  = '%_00'
        p_program = sy-repid
      TABLES
        p_exclude = exclude_buttons.
  ENDMETHOD.

  METHOD handle_user_command.

    CASE command.
      WHEN 'FC01'. " Toggle Mode
        IF current_mode = 'V'.
          current_mode = 'A'.
        ELSE.
          current_mode = 'V'.
        ENDIF.
        render_list_view( ).
        render_editor_view( ).
        update_button( ).

      WHEN 'FC02'. " Save
        IF current_mode = 'A'.
          save_solution( ).
        ENDIF.
    ENDCASE.

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

    IF current_mode = 'V'.
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
      me->code_editor->set_readonly_mode( 1 ).
    ELSE.
      current_add_ex_id = me->exercise_outs[ e_row_id ]-ex_id.
      IF code_editor IS NOT BOUND.
        render_editor_view( ).
      ENDIF.

      DATA(initial_code) = VALUE string_table( ).
      APPEND '* Write your solution here' TO initial_code.
      me->code_editor->set_text( table = initial_code ).
      me->code_editor->set_readonly_mode( 0 ).
    ENDIF.

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

    IF me->current_mode = 'V'.
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
    ELSE.
      load_exercises( ).

      field_catalog = VALUE lvc_t_fcat(
          ( fieldname = 'EX_ID' coltext = 'Exercise' outputlen = 10 style = cl_gui_alv_grid=>mc_style_hotspot )
          ( fieldname = 'TITLE' coltext = 'Title' outputlen = 30 )
          ( fieldname = 'SHORT_DESC' coltext = 'Description' outputlen = 50 ) ).

      alv_grid->set_table_for_first_display( EXPORTING is_layout       = VALUE #( no_toolbar = abap_true
                                                                                  cwidth_opt = 'A'
                                                                                  zebra      = abap_true )
                                             CHANGING  it_outtab       = me->exercise_outs
                                                       it_fieldcatalog = field_catalog ).
      alv_grid->refresh_table_display( ).

    ENDIF.
  ENDMETHOD.

  METHOD save_solution.
    DATA: fields TYPE TABLE OF sval.

    IF code_editor IS NOT BOUND. RETURN. ENDIF.
    IF current_add_ex_id IS INITIAL.
      MESSAGE 'Please select an exercise first.' TYPE 'S'.
      RETURN.
    ENDIF.

    fields = VALUE #( ( tabname = 'ZTEX_SUBMISSION' fieldname = 'USER_ID' field_attr = ' ' )
                      ( tabname = 'ZTEX_SUBMISSION' fieldname = 'NAME_TEXT' field_attr = ' ' ) ).

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title = 'Enter Submission Details'
      TABLES
        fields      = fields.

    DATA(l_user_id) = VALUE #( fields[ fieldname = 'USER_ID' ]-value OPTIONAL ).
    DATA(l_name_text) = VALUE #( fields[ fieldname = 'NAME_TEXT' ]-value OPTIONAL ).

    IF l_user_id IS INITIAL.
      MESSAGE 'User ID is required.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA(code_lines) = VALUE string_table( ).
    code_editor->get_text( IMPORTING table = code_lines ).
    DATA(l_code_string) = concat_lines_of( table = code_lines sep = cl_abap_char_utilities=>cr_lf ).

    DATA(l_submission) = VALUE ztex_submission(
      ex_id = current_add_ex_id
      user_id = l_user_id
      name_text = l_name_text
      user_code = l_code_string
      status = 'S'
      first_success_date = sy-datum
      first_success_time = sy-uzeit
      last_date = sy-datum
      last_time = sy-uzeit
    ).

    MODIFY ztex_submission FROM l_submission.
    COMMIT WORK.
    MESSAGE 'Solution Saved Successfully' TYPE 'S'.

  ENDMETHOD.

  METHOD load_exercises.

    SELECT ex_id,
           title,
           short_desc
      FROM ztex_desc
      INTO CORRESPONDING FIELDS OF TABLE @me->exercise_outs.

  ENDMETHOD.

  METHOD start.
    me->exercise_id = ex_id.

    update_button( ).

    initial_layout( ).
    render_list_view( ).
    render_editor_view( ).

  ENDMETHOD.

ENDCLASS.



DATA solutions TYPE REF TO lcl_solutions.

SELECTION-SCREEN FUNCTION KEY 1.
SELECTION-SCREEN FUNCTION KEY 2.

PARAMETERS p_dummy TYPE c.

INITIALIZATION.

  DATA ex_id TYPE ztex_desc-ex_id.

  IMPORT ex_id = ex_id FROM MEMORY ID 'EXERCISE_ID'.

  solutions = NEW #( ).
  solutions->start( ex_id ).

AT SELECTION-SCREEN.
  solutions->handle_user_command( sscrfields-ucomm ).
