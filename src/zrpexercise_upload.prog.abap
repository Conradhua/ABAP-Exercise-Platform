*&---------------------------------------------------------------------*
*& Report zrpexercise_upload
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zrpexercise_upload.

TYPES: BEGIN OF ty_backup,
         desc       TYPE STANDARD TABLE OF ztex_desc WITH EMPTY KEY,
         submission TYPE STANDARD TABLE OF ztex_submission WITH EMPTY KEY,
       END OF ty_backup.



PARAMETERS p_file TYPE string LOWER CASE OBLIGATORY.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f4_file.

START-OF-SELECTION.
  PERFORM upload.


FORM upload.
  DATA xml_lines TYPE string_table.
  DATA xml_content TYPE string.
  DATA backup_payload TYPE ty_backup.

  TRY.
      cl_gui_frontend_services=>gui_upload(
        EXPORTING
          filename = p_file
          filetype = 'ASC'
        CHANGING
          data_tab = xml_lines ).
    CATCH cx_root INTO DATA(root_error).
      MESSAGE root_error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  CONCATENATE LINES OF xml_lines INTO xml_content
  SEPARATED BY cl_abap_char_utilities=>cr_lf.

  TRY.
      CALL TRANSFORMATION id SOURCE XML xml_content RESULT backup = backup_payload.

    CATCH cx_root INTO root_error.
      MESSAGE root_error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  MODIFY ztex_desc FROM TABLE backup_payload-desc.
  MODIFY ztex_submission FROM TABLE backup_payload-submission.
  IF sy-subrc = 0 .
    COMMIT WORK.
    MESSAGE 'Upload Successfully.' TYPE 'S'.
  ELSE.
    MESSAGE 'Upload Error.' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.


ENDFORM.

FORM f4_file.
  DATA file_tables TYPE filetable.
  DATA return_count TYPE i.
  DATA user_action TYPE i.

  cl_gui_frontend_services=>file_open_dialog(
    EXPORTING
      file_filter             = 'XML (*.xml)|*.xml|All (*.*)|*.*|'
    CHANGING
      file_table              = file_tables
      rc                      = return_count
      user_action             = user_action
    EXCEPTIONS
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      not_supported_by_gui    = 4
      OTHERS                  = 5
  ).

  IF user_action = cl_gui_frontend_services=>action_cancel
   OR return_count = 0.
    CLEAR p_file.
    RETURN.
  ENDIF.

  READ TABLE file_tables INTO DATA(file_table) INDEX 1.
  IF sy-subrc = 0.
    p_file = file_table-filename.
  ENDIF.



ENDFORM.
