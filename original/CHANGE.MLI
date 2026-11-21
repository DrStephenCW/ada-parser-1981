EXPR PENNIES(N);
  BEGIN RETURN 1; END;

EXPR NICKELS(N);
  BEGIN NEW ANS;
    ANS _ 0;
    WHILE ~(N LT 0) DO:
      BEGIN
        ANS _ ANS + PENNIES(N);
        N _ N - 5;
      END;
    RETURN ANS;
  END;

EXPR DIMES(N);
  BEGIN NEW ANS;
    ANS _ 0;
    WHILE ~(N LT 0) DO:
      BEGIN
        ANS _ ANS + NICKELS(N);
        N _ N - 10;
      END;
    RETURN ANS;
  END;

EXPR QUARTERS(N);
  BEGIN NEW ANS;
    ANS _ 0;
    WHILE ~(N LT 0) DO:
      BEGIN
        ANS _ ANS + DIMES(N);
        N _ N - 25;
      END;
    RETURN ANS;
  END;
 
EXPR HALVES(N);
  BEGIN NEW ANS;
    ANS _ 0;
    WHILE ~(N LT 0) DO:
      BEGIN
        ANS _ ANS + QUARTERS(N);
        N _ N - 50;
      END;
    RETURN ANS;
  END;

EXPR CHANGE(N);
  BEGIN
    RETURN HALVES(N);
  END;
