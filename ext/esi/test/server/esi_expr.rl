/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
%%{
  machine esi_expr;

  action equal {
    printf("equal to\n");
  }

  action not_equal {
  }

  action greater_than {
  }
  action less_than {
  }

  action greater_than_or_equal {
  }

  action less_than_or_equal {
  }

  action and_oper {
  }

  action or_oper {
  }

  action not_oper {
  }

  action http_cookie {
    this->prune_seq("$(HTTP_COOKI");
    m_variable = ESI::Parser::HTTP_COOKIE;
  }

  action query_string {
    this->prune_seq("$(QUERY_STRIN");
    m_variable = ESI::Parser::QUERY_STRING;
  }

  esi_boolean = ('==' @equal |
                 '!=' @not_equal |
                 '>'  @greater_than |
                 '<'  @less_than |
                 '>=' @greater_than_or_equal |
                 '<=' @less_than_or_equal |
                 '&'  @and_oper |
                 '|'  @or_oper );

  esi_variable = ('$(' @esi_capture_value space* (
                       'HTTP_COOKIE'  @http_cookie |
                       'QUERY_STRING' @query_string )
                       ('{' (alnum @attr_value)+ '}')? ')' );

	esi_value = ("'" alnum+ "'");
  esi_var = ( esi_variable | esi_value );
  esi_pos_expr =  ( esi_var space* esi_boolean space* esi_var );
  esi_neg_expr = '!' @not_oper space* '(' space* esi_pos_expr  space* ')';
  esi_expr = (esi_pos_expr | esi_neg_expr);

	esi_test = '"' esi_expr '"';
}%%
