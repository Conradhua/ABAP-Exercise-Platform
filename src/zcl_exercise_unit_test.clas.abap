CLASS zcl_exercise_unit_test DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF result,
             status       TYPE string,
             code_snippet TYPE string,
             msg          TYPE string,
           END OF result,
           tt_results TYPE STANDARD TABLE OF result WITH EMPTY KEY.

    CLASS-DATA results    TYPE STANDARD TABLE OF result.

    CLASS-DATA gt_results TYPE string_table.

    CLASS-METHODS assert_equals
      IMPORTING act          TYPE any
                exp          TYPE any
                msg          TYPE string
                code_snippet TYPE string.

    CLASS-METHODS assert_differs
      IMPORTING act          TYPE any
                exp          TYPE any
                msg          TYPE string
                code_snippet TYPE string.

    CLASS-METHODS get_results
      RETURNING VALUE(rt_results) TYPE  tt_results.

    CLASS-METHODS clear_results.

  PRIVATE SECTION.
    CLASS-METHODS to_string IMPORTING val        TYPE any
                            RETURNING VALUE(res) TYPE string.
ENDCLASS.


CLASS zcl_exercise_unit_test IMPLEMENTATION.
  METHOD assert_equals.
    DATA msg_line    TYPE string.
    DATA code_line   TYPE string.
    DATA status_line TYPE string.

    DATA exp_str     TYPE string.
    DATA act_str     TYPE string.

    exp_str = to_string( exp ).
    act_str = to_string( act ).


    code_line = code_snippet.

    TRY.
        cl_abap_unit_assert=>assert_equals( exp = exp
                                            act = act ).
        msg_line = |[PASS] { msg } - Expected: { exp_str }, Actual: { act_str }|.
        status_line = 'PASS'.
      CATCH cx_root INTO DATA(root_error).
        msg_line = |[FAIL] { msg } - Expected: { exp_str }, Actual: { act_str }|.
        status_line = 'FAIL'.
    ENDTRY.

    results = VALUE #( BASE results
                       ( status       = status_line
                         code_snippet = code_line
                         msg          = msg_line ) ).
  ENDMETHOD.

  METHOD assert_differs.
    DATA msg_line    TYPE string.
    DATA code_line   TYPE string.
    DATA status_line TYPE string.

    DATA exp_str     TYPE string.
    DATA act_str     TYPE string.

    exp_str = to_string( exp ).
    act_str = to_string( act ).


    code_line = code_snippet.

    TRY.
        cl_abap_unit_assert=>assert_differs( exp = exp
                                             act = act ).
        msg_line = |[PASS] { msg } - Expected: { exp_str }, Actual: { act_str }|.
        status_line = 'PASS'.
      CATCH cx_root INTO DATA(root_error).
        msg_line = |[FAIL] { msg } - Expected: { exp_str }, Actual: { act_str }|.
        status_line = 'FAIL'.
    ENDTRY.
    results = VALUE #( BASE results
                       ( status       = status_line
                         code_snippet = code_line
                         msg          = msg_line ) ).
  ENDMETHOD.

  METHOD get_results.
    rt_results = results.
  ENDMETHOD.

  METHOD clear_results.
    CLEAR results.
  ENDMETHOD.

  METHOD to_string.

    DATA(type_descr) = cl_abap_typedescr=>describe_by_data( val ).
    IF type_descr->kind = cl_abap_typedescr=>kind_elem.
      res = val.
    ELSE.
      TRY.
          res = /ui2/cl_json=>serialize( data = val compress = abap_true pretty_name = /ui2/cl_json=>pretty_mode-low_case ).
        CATCH cx_root.
          res = 'Complex Data (Serialization Failed)'.
      ENDTRY.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
