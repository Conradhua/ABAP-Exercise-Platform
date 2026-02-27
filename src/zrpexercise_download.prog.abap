*&---------------------------------------------------------------------*
*& Report zrpexercise_download
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zrpexercise_download.

TYPES: BEGIN OF ty_backup,
         desc       TYPE STANDARD TABLE OF ztex_desc WITH EMPTY KEY,
         submission TYPE STANDARD TABLE OF ztex_submission WITH EMPTY KEY,
       END OF ty_backup.

PARAMETERS p_file TYPE string LOWER CASE OBLIGATORY.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f4_file.

START-OF-SELECTION.
  PERFORM download.


FORM download.

  DATA xml_content TYPE string.
  DATA xml_lines TYPE string_table.

  SELECT * FROM ztex_desc INTO TABLE @DATA(desc_records).
  SELECT * FROM ztex_submission INTO TABLE @DATA(submission_records).

  DATA(backup_payload) = VALUE ty_backup( desc = desc_records
                                          submission = submission_records ).

  TRY.
      CALL TRANSFORMATION id SOURCE backup = backup_payload
      RESULT XML xml_content.
    CATCH cx_root INTO DATA(root_error).
      MESSAGE root_error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.

  SPLIT xml_content AT cl_abap_char_utilities=>cr_lf INTO TABLE xml_lines.

  TRY.
      cl_gui_frontend_services=>gui_download(
       EXPORTING
        filename = p_file
        filetype = 'ASC'
       CHANGING
        data_tab = xml_lines ).

    CATCH cx_root INTO root_error.
      MESSAGE root_error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  MESSAGE 'Download Successfully.' TYPE 'S'.

ENDFORM.


FORM f4_file.
  DATA filename TYPE string.
  DATA directory_path TYPE string.
  DATA user_action TYPE i.

  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      default_extension         = 'xml'
      file_filter               = 'XML (*.xml)|*.xml|All (*.*)|*.*|'
    CHANGING
      filename                  = filename
      path                      = directory_path
      fullpath                  = p_file
      user_action               = user_action
    EXCEPTIONS
      cntl_error                = 1
      error_no_gui              = 2
      not_supported_by_gui      = 3
      invalid_default_file_name = 4
      OTHERS                    = 5
  ).

  IF user_action = cl_gui_frontend_services=>action_cancel.
    CLEAR p_file.
  ENDIF.

ENDFORM.
