*&---------------------------------------------------------------------*
*& Report zrpexercise002
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zrpexercise002.
TABLES sscrfields.
TYPE-POOLS icon.

INTERFACE lif_const.
  CONSTANTS mode_list    TYPE c LENGTH 1      VALUE 'L'.
  CONSTANTS mode_editor  TYPE c LENGTH 1      VALUE 'E'.
  CONSTANTS status_pass  TYPE ze_ex_status_cr VALUE 'S'.
  CONSTANTS status_fail  TYPE ze_ex_status_cr VALUE 'E'.
  CONSTANTS status_part  TYPE ze_ex_status_cr VALUE 'P'.
  CONSTANTS col_action   TYPE string          VALUE 'ACTION_BTN'.
  CONSTANTS cmd_run_test TYPE sy-ucomm        VALUE 'RUN_TEST'.
  CONSTANTS cmd_back     TYPE sy-ucomm        VALUE 'BACK'.
  CONSTANTS icon_pass    TYPE string          VALUE '&#9989;'.    " Green Check
  CONSTANTS icon_fail    TYPE string          VALUE '&#10060;'.   " Red X
ENDINTERFACE.


CLASS lcl_application DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_alv_out,
             ex_id             TYPE ztex_desc-ex_id,
             title             TYPE ztex_desc-title,
             short_desc        TYPE ztex_desc-short_desc,
             status            TYPE c LENGTH 4,
             edit_code_btn     TYPE c LENGTH 20,
             view_solution_btn TYPE c LENGTH 20,
             style             TYPE lvc_t_styl,
           END OF ty_alv_out.

    METHODS start.
    METHODS handle_user_command IMPORTING !command TYPE sy-ucomm.

    " Event handler
    METHODS on_alv_button_click FOR EVENT button_click OF cl_gui_alv_grid
      IMPORTING es_col_id es_row_no.

    METHODS on_alv_hotspot_click FOR EVENT hotspot_click OF cl_gui_alv_grid
      IMPORTING e_row_id.

  PRIVATE SECTION.
    " UI Components
    DATA docking_container   TYPE REF TO cl_gui_docking_container.
    DATA splitter_main       TYPE REF TO cl_gui_splitter_container.
    DATA container_left      TYPE REF TO cl_gui_container.
    DATA container_right     TYPE REF TO cl_gui_container.
    DATA alv_grid            TYPE REF TO cl_gui_alv_grid.
    DATA abap_editor         TYPE REF TO cl_gui_abapedit.
    DATA html_viewer         TYPE REF TO cl_gui_html_viewer.

    " State
    DATA current_mode        TYPE c LENGTH 1                       VALUE lif_const=>mode_list.
    DATA current_exercise_id TYPE ztex_desc-ex_id.
    DATA active_exercise     TYPE ztex_desc.
    DATA is_test_passed      TYPE abap_bool                        VALUE abap_false.

    DATA mt_alv_outputs      TYPE STANDARD TABLE OF ty_alv_out WITH EMPTY KEY.

    " Internal Methods
    METHODS initialize_layout.

    " View Rendering
    METHODS render_list_view.
    METHODS render_editor_view.
    METHODS render_html IMPORTING html_lines TYPE string_table.
    METHODS update_toolbar.

    " Logic
    METHODS load_exercise_data IMPORTING exercise_id TYPE ztex_desc-ex_id.
    METHODS format_editor_code.
    METHODS execute_tests.

    METHODS generate_dynamic_subroutine IMPORTING code_source      TYPE string_table
                                        RETURNING VALUE(prog_name) TYPE program.

    METHODS save_submission IMPORTING !status TYPE ze_ex_status_cr
                                      !code   TYPE string.

ENDCLASS.


CLASS lcl_application IMPLEMENTATION.
  METHOD execute_tests.
    DATA editor_content TYPE string_table.
    DATA full_source    TYPE string_table.
    DATA html_dynamics  TYPE string_table.

    format_editor_code( ).

    abap_editor->get_text( IMPORTING table = editor_content ).

    " Merge user code + Test code
    APPEND LINES OF editor_content TO full_source.
    DATA(test_code_lines) = VALUE string_table( ).
    SPLIT active_exercise-test_code AT cl_abap_char_utilities=>cr_lf
          INTO TABLE test_code_lines.
    APPEND LINES OF test_code_lines TO full_source.

    " Generate program and run
    DATA(prog_name) = generate_dynamic_subroutine( full_source ).

    IF prog_name IS NOT INITIAL.
      " Begin Execute result in HTML
      APPEND '<div class="result-section">' TO html_dynamics.
      APPEND '<h3>Test Results:</h3>' TO html_dynamics.
      PERFORM execute_tests IN PROGRAM (prog_name) IF FOUND.
      DATA(execute_results) = zcl_exercise_unit_test=>get_results( ).
      zcl_exercise_unit_test=>clear_results( ).
      is_test_passed = abap_true.
      LOOP AT execute_results INTO DATA(execute_result).
        IF execute_result CS 'Fail'.
          APPEND |<div class="fail">X { execute_result }</div>| TO html_dynamics.
          is_test_passed = abap_false.
        ELSE.
          APPEND |<div class="pass">O { execute_result }</div>| TO html_dynamics.
        ENDIF.
      ENDLOOP.
      APPEND '</div>' TO html_dynamics.
      " End

      " Auto submit when test pass
      DATA submit_code TYPE c LENGTH 1.
      DATA text_question TYPE c LENGTH 100.

      text_question = COND #( WHEN is_test_passed = abap_true
                              THEN 'Test passed. Submit the code?'
                              ELSE 'Test fail. Do you need to save the code?' ).

      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar              = 'Confirmation'
          text_question         = text_question
          text_button_1         = 'Yes'
          icon_button_1         = 'ICON_OKAY'
          text_button_2         = 'No'
          icon_button_2         = 'ICON_CANCEL'
          default_button        = '1'
          display_cancel_button = abap_false
        IMPORTING
          answer                = submit_code.
      IF submit_code = '1'.
        DATA(code_submission) = concat_lines_of( table = editor_content
                                                 sep = cl_abap_char_utilities=>cr_lf ).
        save_submission( status = COND #( WHEN is_test_passed = abap_true THEN lif_const=>status_pass
                                          ELSE lif_const=>status_fail )
                         code = code_submission ).

      ENDIF.

      DATA(html_lines) = VALUE string_table( ).
      SPLIT active_exercise-html_desc AT cl_abap_char_utilities=>cr_lf INTO TABLE html_lines.
      DATA(delete_index) = line_index( html_lines[ table_line = '{{RESULT_SECTION}}' ] ).
      IF delete_index IS NOT INITIAL.
        DELETE html_lines INDEX delete_index.
        INSERT LINES OF html_dynamics INTO html_lines INDEX delete_index.
      ENDIF.
      render_html( html_lines ).
    ENDIF.

    update_toolbar( ).
  ENDMETHOD.

  METHOD generate_dynamic_subroutine.
    DATA prog_message TYPE string.
    DATA prog_line    TYPE i.
    DATA prog_word    TYPE string.

    GENERATE SUBROUTINE POOL code_source
             NAME prog_name
             MESSAGE prog_message
             LINE prog_line
             WORD prog_word.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    " Display error in HTML
    DATA(error_htmls) = VALUE string_table( ).
    APPEND '<h3>Syntax Error</h3>' TO error_htmls.
    APPEND |<p style="color:red">Error: { prog_message } at line { prog_line } ({ prog_word })</p>|
           TO error_htmls.

    DATA(html_lines) = VALUE string_table( ).
    SPLIT active_exercise-html_desc AT cl_abap_char_utilities=>cr_lf INTO TABLE html_lines.
    DATA(delete_index) = line_index( html_lines[ table_line = '{{RESULT_SECTION}}' ] ).
    IF delete_index IS NOT INITIAL.
      DELETE html_lines INDEX delete_index.
      INSERT LINES OF error_htmls INTO html_lines INDEX delete_index.
    ENDIF.
    render_html( html_lines ).
  ENDMETHOD.

  METHOD handle_user_command.
    CASE command.
      WHEN 'FC01'. " Run tests
        IF current_mode = lif_const=>mode_editor.
          execute_tests( ).
        ENDIF.
      WHEN 'FC02'. " Submit
        IF current_mode = lif_const=>mode_editor.
          execute_tests( ).
        ENDIF.
      WHEN 'E' OR 'EXIT' OR 'CANC'.
        IF current_mode = lif_const=>mode_editor.
          me->start( ).
          CLEAR sscrfields-ucomm.
          LEAVE TO SCREEN sy-dynnr.
        ENDIF.
    ENDCASE.
  ENDMETHOD.

  METHOD initialize_layout.
    CHECK docking_container IS NOT BOUND.

    docking_container = NEW #( side      = cl_gui_docking_container=>dock_at_bottom
                               extension = 9999 ).
    splitter_main     = NEW #( parent  = docking_container
                               rows    = 1
                               columns = 2 ).

    container_left  = splitter_main->get_container( row    = 1
                                                    column = 1 ).
    container_right = splitter_main->get_container( row    = 1
                                                    column = 2 ).

    " HTML Viewer is always present in the right container
    html_viewer = NEW #( parent = container_right ).
  ENDMETHOD.

  METHOD load_exercise_data.
    current_exercise_id = exercise_id.

    is_test_passed = abap_false.

    SELECT SINGLE * FROM ztex_desc
      WHERE ex_id = @exercise_id
      INTO @active_exercise.
    IF sy-subrc = 0.
      " Switch to editor
      render_editor_view( ).

      " Load HTML Description
      DATA(html_lines) = VALUE string_table( ).
      SPLIT active_exercise-html_desc AT cl_abap_char_utilities=>cr_lf INTO TABLE html_lines.
      DATA(delete_index) = line_index( html_lines[ table_line = '{{RESULT_SECTION}}' ] ).
      IF delete_index IS NOT INITIAL.
        DELETE html_lines INDEX delete_index.
      ENDIF.
      render_html( html_lines ).
    ENDIF.
  ENDMETHOD.

  METHOD on_alv_button_click.
    DATA ex_id TYPE c LENGTH 3.

    CASE es_col_id-fieldname.
      WHEN 'EDIT_CODE_BTN'.

        ex_id = VALUE #( mt_alv_outputs[ es_row_no-row_id ]-ex_id OPTIONAL ).

        IF ex_id IS NOT INITIAL.
          load_exercise_data( ex_id ).
        ENDIF.

      WHEN 'VIEW_SOLUTION_BTN'.

        ex_id = VALUE #( mt_alv_outputs[ es_row_no-row_id ]-ex_id OPTIONAL ).
        IF ex_id IS NOT INITIAL.
          EXPORT ex_id = ex_id TO MEMORY ID 'EXERCISE_ID'.
          SUBMIT zrpexercise003 VIA SELECTION-SCREEN AND RETURN.
        ENDIF.

    ENDCASE.
  ENDMETHOD.

  METHOD on_alv_hotspot_click.
    CHECK e_row_id IS NOT INITIAL.

    DATA ex_id TYPE c LENGTH 3.
    alv_grid->get_current_cell( IMPORTING e_value = ex_id ).

    IF ex_id IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE html_desc FROM ztex_desc
      WHERE ex_id = @ex_id
      INTO @DATA(exercise_desc_html).
    IF sy-subrc = 0.
      DATA(html_lines) = VALUE string_table( ).
      SPLIT exercise_desc_html AT cl_abap_char_utilities=>cr_lf INTO TABLE html_lines.
      DATA(delete_index) = line_index( html_lines[ table_line = '{{RESULT_SECTION}}' ] ).
      IF delete_index IS NOT INITIAL.
        DELETE html_lines INDEX delete_index.
      ENDIF.
      render_html( html_lines ).
    ENDIF.
  ENDMETHOD.

  METHOD render_editor_view.
    current_mode = lif_const=>mode_editor.

    " 1. Hide ALV
    IF alv_grid IS BOUND.
      alv_grid->set_visible( abap_false ).
    ENDIF.

    " 2. Initialize Editor if needed
    IF abap_editor IS NOT BOUND.
      abap_editor = NEW #( parent = container_left ).
      abap_editor->set_statusbar_mode( 1 ).
      abap_editor->set_toolbar_mode( 1 ).
    ENDIF.

    abap_editor->set_visible( abap_true ).

    " 3. Determine code to load
    "    Check if user has a previous submission
    SELECT SINGLE user_code FROM ztex_submission
      WHERE ex_id = @active_exercise-ex_id
      INTO @DATA(saved_code).

    " 4. Fetch initial code
    SELECT SINGLE init_code FROM ztex_desc
      WHERE ex_id = @active_exercise-ex_id
      INTO @DATA(init_code).

    DATA(code_content) = COND string( WHEN saved_code IS NOT INITIAL
                                      THEN saved_code
                                      ELSE init_code ).
    DATA(code_lines) = VALUE string_table( ).
    SPLIT code_content AT cl_abap_char_utilities=>cr_lf INTO TABLE code_lines.

    abap_editor->set_text( table = code_lines ).

    update_toolbar( ).
  ENDMETHOD.

  METHOD render_html.
    DATA html_current_code TYPE w3htmltab.
    DATA url               TYPE c LENGTH 255.

    IF html_lines IS NOT INITIAL.
      html_current_code = html_lines.
    ENDIF.
    html_viewer->load_data( IMPORTING assigned_url = url
                            CHANGING  data_table   = html_current_code ).

    html_viewer->show_url( url = url ).
  ENDMETHOD.

  METHOD render_list_view.
    current_mode = lif_const=>mode_list.

    " 1. Hide Editor if active
    IF abap_editor IS BOUND.
      abap_editor->set_visible( abap_false ).
    ENDIF.

    " 2. Initialize ALV if needed
    IF alv_grid IS NOT BOUND.
      alv_grid = NEW #( i_parent = container_left ).
      SET HANDLER on_alv_button_click FOR alv_grid.
      SET HANDLER on_alv_hotspot_click FOR alv_grid.
    ENDIF.

    alv_grid->set_visible( abap_true ).

    " 3. Fetch data

    SELECT ztex_desc~ex_id,
           ztex_desc~title,
           ztex_desc~short_desc,
           CASE ztex_submission~status
                WHEN 'S' THEN '@08@' " icon_green_light
                WHEN 'P' THEN '@09@' " icon_yellow_light
                WHEN 'E' THEN '@0A@' " icon_red_light
                ELSE ' '
           END                         AS status,
           'Start to Edit'             AS edit_code_btn,
           CASE WHEN ztex_submission~status = 'S' THEN 'View Solutions'
                ELSE ' '
            END AS view_solution_btn
      FROM ztex_desc
             LEFT OUTER JOIN
               ztex_submission ON ztex_desc~ex_id = ztex_submission~ex_id
      INTO CORRESPONDING FIELDS OF TABLE @mt_alv_outputs.

    " ALV Setting: 1. Field catalog
    DATA(field_catalog) = VALUE lvc_t_fcat(
        ( fieldname = 'EX_ID' coltext = 'ID' outputlen = 10 style = cl_gui_alv_grid=>mc_style_hotspot )
        ( fieldname = 'TITLE' coltext = 'Title' outputlen = 40 )
        ( fieldname = 'SHORT_DESC' coltext = 'Short Descripiton' outputlen = 100 )
        ( fieldname = 'STATUS' coltext = 'Status' outputlen = 4 )
        ( fieldname = 'EDIT_CODE_BTN' coltext = ' ' style = cl_gui_alv_grid=>mc_style_button )
        ( fieldname = 'VIEW_SOLUTION_BTN' coltext = ' ' ) ).

    " ALV Setting: 2. Customize Field style
    LOOP AT mt_alv_outputs ASSIGNING FIELD-SYMBOL(<alv_output>).

      IF <alv_output>-view_solution_btn IS NOT INITIAL.
        <alv_output>-style = VALUE lvc_t_styl( ( fieldname = 'VIEW_SOLUTION_BTN'
                                                 style = cl_gui_alv_grid=>mc_style_button ) ).
      ENDIF.

    ENDLOOP.

    " ALV Setting: 3. initial ALV grid
    alv_grid->set_table_for_first_display( EXPORTING is_layout       = VALUE #( no_toolbar = abap_true
                                                                                cwidth_opt = 'A'
                                                                                zebra      = abap_true
                                                                                stylefname = 'STYLE' )
                                           CHANGING  it_outtab       = mt_alv_outputs
                                                     it_fieldcatalog = field_catalog ).

    update_toolbar( ).
  ENDMETHOD.

  METHOD save_submission.
    " Get the user name text
    SELECT SINGLE adrp~name_text
      FROM usr21
             INNER JOIN
               adrp ON usr21~persnumber = adrp~persnumber
      WHERE usr21~bname = @sy-uname
      INTO @DATA(name_text).

    DATA(submission) = VALUE ztex_submission( ex_id     = current_exercise_id
                                              user_id   = sy-uname
                                              name_text = name_text
                                              status    = status
                                              user_code = code
                                              last_date = sy-datum
                                              last_time = sy-uzeit ).

    " Get existing to preserve first success date
    SELECT SINGLE first_success_date,
                  first_success_time
      FROM ztex_submission
      WHERE ex_id   = @me->current_exercise_id
        AND user_id = @sy-uname
      INTO ( @submission-first_success_date, @submission-first_success_time ).

    IF     status = lif_const=>status_pass
       AND submission-first_success_date IS INITIAL.
      submission-first_success_date = sy-datum.
      submission-first_success_time = sy-uzeit.
    ENDIF.

    MODIFY ztex_submission FROM submission.
    COMMIT WORK.
    MESSAGE 'Submission saved.' TYPE 'S'.

  ENDMETHOD.

  METHOD start.
    initialize_layout( ).
    render_list_view( ).

    " Show Welcome HTML
    render_html( VALUE #( ( `<html><body style="font-family: Arial, sans-serif; padding: 20px;">` )
                          ( `<h2>Welcome to the ABAP Exercise Platform</h2>` )
                          ( `<p>Please select an exercise from the list on the left to start coding.</p>` )
                          ( `</body></html>` ) ) ).
  ENDMETHOD.

  METHOD update_toolbar.
    DATA exclude_buttons TYPE TABLE OF sy-ucomm.

    " Always exclude standard print/execute
    exclude_buttons = VALUE #( ( 'ONLI' )
                               ( 'PRIN' )
                               ( 'SPOS' ) ).

    IF current_mode = lif_const=>mode_list.
      " Hide 'Run Test' in list mode
      APPEND 'FC01' TO exclude_buttons.
    ELSE.
      " Show 'Run test' in editor mode
      sscrfields-functxt_01 = |{ icon_execute_object } Run Tests|.

    ENDIF.

    IF me->is_test_passed = abap_true.
      sscrfields-functxt_02 = |{ icon_system_save } Submit|.
    ELSE.
      " Hide 'Submit' button while test fail
      APPEND 'FC02' TO exclude_buttons.

    ENDIF.

    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING
        p_status  = '%_00'
        p_program = sy-repid
      TABLES
        p_exclude = exclude_buttons.
  ENDMETHOD.

  METHOD format_editor_code.
    DATA code_lines TYPE TABLE OF string.

    CHECK abap_editor IS BOUND.

    " Get editor content
    abap_editor->get_text( IMPORTING table = code_lines ).

    IF code_lines IS INITIAL.
      RETURN.
    ENDIF.

    CALL FUNCTION 'PRETTY_PRINTER'
      EXPORTING
        inctoo             = abap_false
      TABLES
        ntext              = code_lines
        otext              = code_lines
      EXCEPTIONS
        enqueue_table_full = 1
        include_enqueued   = 2
        include_readerror  = 3
        include_writeerror = 4
        OTHERS             = 5.
    IF sy-subrc = 0.

      " Rewrite the formatted code back to the editor
      abap_editor->set_text( table = code_lines ).

    ENDIF.
  ENDMETHOD.
ENDCLASS.


DATA app_instance TYPE REF TO lcl_application.


SELECTION-SCREEN FUNCTION KEY 1. " for run test button
SELECTION-SCREEN FUNCTION KEY 2. " for submit button
PARAMETERS p_dummy TYPE c.


INITIALIZATION.
  app_instance = NEW #( ).
  app_instance->start( ).

AT SELECTION-SCREEN ON EXIT-COMMAND.
  app_instance->handle_user_command( sscrfields-ucomm  ).

AT SELECTION-SCREEN.
  app_instance->handle_user_command( sscrfields-ucomm  ).
