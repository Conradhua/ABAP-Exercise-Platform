*&---------------------------------------------------------------------*
*& Report zrpex001
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zrpex001.
TABLES sscrfields.

" -----------------------------------------------------------------------
" Selection Screen
" -----------------------------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK exercise_block WITH FRAME TITLE title_01.
  PARAMETERS: s_ex_id TYPE ztex_desc-ex_id,
              s_title TYPE ztex_desc-title,
              s_desc  TYPE ztex_desc-short_desc.
SELECTION-SCREEN END OF BLOCK exercise_block.

SELECTION-SCREEN FUNCTION KEY 1. " Load
SELECTION-SCREEN FUNCTION KEY 2. " Edit / Display
SELECTION-SCREEN FUNCTION KEY 3. " Save
SELECTION-SCREEN FUNCTION KEY 4. " Delete
SELECTION-SCREEN FUNCTION KEY 5. " New

CLASS exercise_app DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF command,
        load   TYPE sy-ucomm VALUE 'FC01',
        toggle TYPE sy-ucomm VALUE 'FC02',
        save   TYPE sy-ucomm VALUE 'FC03',
        delete TYPE sy-ucomm VALUE 'FC04',
        new    TYPE sy-ucomm VALUE 'FC05',
      END OF command.

    " event handlers
    METHODS on_user_command IMPORTING ucomm TYPE sy-ucomm.
    METHODS on_before_output.
    METHODS on_value_request_id.

  PRIVATE SECTION.
    " UI & Containers & Editors
    DATA docking_container TYPE REF TO cl_gui_docking_container.
    DATA main_splitter     TYPE REF TO cl_gui_splitter_container.
    DATA right_splitter    TYPE REF TO cl_gui_splitter_container.
    DATA html_editor       TYPE REF TO cl_gui_textedit.
    DATA init_code_editor  TYPE REF TO cl_gui_abapedit.
    DATA test_code_editor  TYPE REF TO cl_gui_abapedit.

    " Status variables
    DATA is_data_loaded    TYPE abap_bool                        VALUE abap_false.
    DATA is_edit_mode      TYPE abap_bool                        VALUE abap_false.

    " UI Logic
    METHODS initialize_ui.
    METHODS update_toolbar.
    METHODS update_editor_state.
    METHODS set_default_content.

    " Business Logic
    METHODS load_exercise.
    METHODS save_exercise.
    METHODS create_exercise.
    METHODS toggle_mode.
    METHODS confirm_action RETURNING VALUE(is_confirmed) TYPE abap_bool.

ENDCLASS.

DATA exercise_app TYPE REF TO exercise_app.


INITIALIZATION.
  title_01 = 'Exercise Metadata'.
  exercise_app = NEW #( ).

AT SELECTION-SCREEN OUTPUT.
  exercise_app->on_before_output( ).

AT SELECTION-SCREEN.
  exercise_app->on_user_command( sscrfields-ucomm ).

AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_ex_id.
  exercise_app->on_value_request_id( ).



CLASS exercise_app IMPLEMENTATION.
  METHOD confirm_action.
    DATA user_response TYPE c LENGTH 1.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING titlebar              = 'Confirmation'
                text_question         = 'The data will be modified, Continue?'
                text_button_1         = 'Yes'
                icon_button_1         = 'ICON_OKAY'
                text_button_2         = 'No'
                icon_button_2         = 'ICON_CANCEL'
                default_button        = '1'
                display_cancel_button = abap_false
      IMPORTING answer                = user_response.

    is_confirmed = xsdbool( user_response = '1' ).
  ENDMETHOD.

  METHOD create_exercise.
    SELECT MAX( ex_id ) FROM ztex_desc
      INTO @DATA(last_id).

    last_id += 1.
    s_ex_id = |{ last_id ALPHA = IN }|.
    CLEAR s_title.

    is_data_loaded = abap_true.
    is_edit_mode = abap_true.

    set_default_content( ).
  ENDMETHOD.

  METHOD initialize_ui.
    " Full screen container
    docking_container = NEW #( side  = cl_gui_docking_container=>dock_at_bottom
                               ratio = 85 ).

    " Main split: Left(HTML) | Right(Code)
    main_splitter = NEW #( parent  = docking_container
                           rows    = 1
                           columns = 2 ).

    " Right split: Up(Initial Code) | Down(Testing Code)
    right_splitter = NEW #( parent  = main_splitter->get_container( row    = 1
                                                                    column = 2 )
                            rows    = 2
                            columns = 1 ).

    " Left HTML editor
    html_editor = NEW #( parent = main_splitter->get_container( row    = 1
                                                                column = 1 ) ).
    html_editor->set_toolbar_mode( 0 ).
    html_editor->set_statusbar_mode( 0 ).

    " Right-Top: Initial Code
    init_code_editor = NEW #( parent = right_splitter->get_container( row    = 1
                                                                      column = 1 ) ).
    init_code_editor->set_toolbar_mode( 0 ).
    init_code_editor->set_statusbar_mode( 1 ).

    " Right-Down: Testing Code
    test_code_editor = NEW #( parent = right_splitter->get_container( row    = 2
                                                                      column = 1 ) ).
    test_code_editor->set_toolbar_mode( 0 ).
    test_code_editor->set_statusbar_mode( 1 ).

    set_default_content( ).
  ENDMETHOD.

  METHOD load_exercise.
    SELECT SINGLE * FROM ztex_desc
      WHERE ex_id = @s_ex_id
      INTO @DATA(exercise_desc).
    IF sy-subrc <> 0.
      MESSAGE 'No data found' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    s_title = exercise_desc-title.
    s_desc  = exercise_desc-short_desc.

    " Set content
    html_editor->set_textstream( text = exercise_desc-html_desc ).

    DATA(init_code) = VALUE string_table( ).
    SPLIT exercise_desc-init_code AT cl_abap_char_utilities=>cr_lf INTO TABLE init_code.
    init_code_editor->set_text( table = init_code ).

    DATA(test_code) = VALUE string_table( ).
    SPLIT exercise_desc-test_code AT cl_abap_char_utilities=>cr_lf INTO TABLE test_code.
    test_code_editor->set_text( table = test_code ).

    is_data_loaded = abap_true.
    is_edit_mode = abap_false.
  ENDMETHOD.

  METHOD on_before_output.
    IF docking_container IS NOT BOUND.
      initialize_ui( ).
    ENDIF.

    update_toolbar( ).
    update_editor_state( ).
  ENDMETHOD.

  METHOD on_user_command.
    CASE ucomm.
      WHEN command-load.
        load_exercise( ).
      WHEN command-toggle.
        toggle_mode( ).
      WHEN command-save.
        IF confirm_action( ).
          save_exercise( ).
        ENDIF.
      WHEN command-new.
        create_exercise( ).
    ENDCASE.
  ENDMETHOD.

  METHOD on_value_request_id.
    TYPES: BEGIN OF help_value_type,
             exe_id TYPE ztex_desc-ex_id,
             title  TYPE ztex_desc-title,
           END OF help_value_type.
    DATA help_values   TYPE TABLE OF help_value_type.
    DATA return_values TYPE TABLE OF ddshretval.

    SELECT ex_id,
           title
      FROM ztex_desc
      INTO TABLE @help_values
      ORDER BY ex_id.

    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING  retfield        = 'EXE_ID'
                 value_org       = 'S'
                 dynpprog        = sy-repid
                 dynpnr          = sy-dynnr
                 dynprofield     = 'S_EX_ID' " Matches parameter name
      TABLES     value_tab       = help_values
                 return_tab      = return_values
      EXCEPTIONS parameter_error = 1
                 no_values_found = 2
                 OTHERS          = 3.

    IF     sy-subrc       = 0
       AND return_values IS NOT INITIAL.
      s_ex_id = return_values[ 1 ]-fieldval.
    ENDIF.
  ENDMETHOD.

  METHOD save_exercise.
    DATA exercise_save TYPE ztex_desc.
    DATA html_content  TYPE string.
    DATA code_lines    TYPE TABLE OF string.

    exercise_save-ex_id      = s_ex_id.
    exercise_save-title      = s_title.
    exercise_save-short_desc = s_desc.

    " Get HTML code
    html_editor->get_textstream( IMPORTING text = html_content ).
    cl_gui_cfw=>flush( ).
    exercise_save-html_desc = html_content.

    " Get Init code
    init_code_editor->get_text( IMPORTING table = code_lines ).
    CONCATENATE LINES OF code_lines INTO exercise_save-init_code
                SEPARATED BY cl_abap_char_utilities=>cr_lf.

    " Get Test code
    test_code_editor->get_text( IMPORTING table = code_lines ).
    CONCATENATE LINES OF code_lines INTO exercise_save-test_code
                SEPARATED BY cl_abap_char_utilities=>cr_lf.

    MODIFY ztex_desc FROM exercise_save.
    IF sy-subrc = 0.
      COMMIT WORK.
      MESSAGE 'Saved successfully.' TYPE 'S'.
      is_edit_mode = abap_false.
    ELSE.
      MESSAGE 'Error saving data.' TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD set_default_content.
    DATA html_defaults TYPE w3htmltab.
    DATA init_codes    TYPE TABLE OF string.
    DATA test_codes    TYPE TABLE OF string.

    APPEND |/* Input HTML Code Here */| TO html_defaults.
    html_editor->set_text_as_stream( html_defaults  ).

    APPEND |" Input initial ABAP Code Here| TO init_codes.
    init_code_editor->set_text( init_codes ).

    APPEND |" Input unit Test Code here| TO test_codes.
    test_code_editor->set_text( test_codes ).
  ENDMETHOD.

  METHOD toggle_mode.
    is_edit_mode = xsdbool( is_edit_mode = abap_false ).
  ENDMETHOD.

  METHOD update_editor_state.
    DATA(readonly_mode) = COND i( WHEN is_edit_mode = abap_true THEN 0 ELSE 1 ).

    IF html_editor IS BOUND.
      html_editor->set_readonly_mode( readonly_mode ).
    ENDIF.

    IF init_code_editor IS BOUND.
      init_code_editor->set_readonly_mode( readonly_mode ).
    ENDIF.

    IF test_code_editor IS BOUND.
      test_code_editor->set_readonly_mode( readonly_mode ).
    ENDIF.
  ENDMETHOD.

  METHOD update_toolbar.
    DATA excluded_functions TYPE TABLE OF sy-ucomm.

    " Setup button text
    sscrfields-functxt_01 = 'Load'.
    sscrfields-functxt_03 = 'Save'.
    sscrfields-functxt_04 = 'Delete'.
    sscrfields-functxt_05 = 'New'.

    " Default exclusions
    APPEND 'ONLI' TO excluded_functions.

    IF is_data_loaded = abap_false.
      excluded_functions = VALUE #( BASE excluded_functions
                                    ( command-toggle )
                                    ( command-save )
                                    ( command-delete ) ).
    ELSE.
      IF is_edit_mode = abap_true.
        sscrfields-functxt_02 = |{ icon_display } Display|.
      ELSE.
        sscrfields-functxt_02 = |{ icon_change } Edit|.
        APPEND command-save TO excluded_functions.
      ENDIF.
    ENDIF.

    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING p_status  = '%_00'
                p_program = sy-repid
      TABLES    p_exclude = excluded_functions.
  ENDMETHOD.
ENDCLASS.
