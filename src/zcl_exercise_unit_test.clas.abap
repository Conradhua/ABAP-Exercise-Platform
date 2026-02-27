CLASS zcl_exercise_unit_test DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-DATA gt_results TYPE string_table.

    CLASS-METHODS assert_equals
      IMPORTING act TYPE any
                exp TYPE any
                msg TYPE string.

    CLASS-METHODS assert_differs
      IMPORTING act TYPE any
                exp TYPE any
                msg TYPE string.

    CLASS-METHODS get_results
      RETURNING VALUE(rt_results) TYPE string_table.

    CLASS-METHODS clear_results.
ENDCLASS.


CLASS zcl_exercise_unit_test IMPLEMENTATION.
  METHOD assert_equals.
    DATA lv_result_line TYPE string.


    TRY.
        cl_abap_unit_assert=>assert_equals( exp = exp
                                            act = act ).
        lv_result_line = |[PASS] { msg } - Expected: { exp }, Actual: { act }|.
      CATCH cx_root INTO DATA(root_error).
        lv_result_line = |[FAIL] { msg } - Expected: { exp }, Actual: { act }|.
    ENDTRY.

*    IF result = abap_true.
*      lv_result_line = |[PASS] { msg } - Expected: { exp }, Actual: { act }|.
*    ELSE.
*      lv_result_line = |[FAIL] { msg } - Expected: { exp }, Actual: { act }|.
*    ENDIF.
    APPEND lv_result_line TO gt_results.
  ENDMETHOD.

  METHOD assert_differs.
    DATA lv_result_line TYPE string.

    TRY.
        cl_abap_unit_assert=>assert_differs( exp = exp
                                             act = act ).
        lv_result_line = |[PASS] { msg } - Expected: { exp }, Actual: { act }|.
      CATCH cx_root INTO DATA(root_error).
        lv_result_line = |[FAIL] { msg } - Expected: { exp }, Actual: { act }|.
    ENDTRY.
    APPEND lv_result_line TO gt_results.
  ENDMETHOD.

  METHOD get_results.
    rt_results = gt_results.
  ENDMETHOD.

  METHOD clear_results.
    CLEAR gt_results.
  ENDMETHOD.
ENDCLASS.
