EXPR PARSE(RULENAME);           % ELIMINATES ! CONSTRUCTION %
  BEGIN NEW RULE,X,             % CALLED WITH RULENAME, NOT RULE %
        SAVED-INPUT-STREAM;

  SAVED-INPUT-STREAM _ INPUT-STREAM;    % REMEMBER CURRENT POSITION %

  IF RULENAME EQ NIL OR INPUT-STREAM EQ NIL THEN RETURN NIL;
                                        % IN CASE OF BUG %

  IF CAR(AEXPLODEC(RULENAME)) LT 65     % IF    PUNCTUATION %
    THEN (IF RULENAME EQ INPUT-STREAM[1] % THEN CHECK FOR MATCH %
            THEN POP(INPUT-STREAM) ALSO RETURN <RULENAME> 
            ELSE RETURN NIL);           % NO MATCH %

  RULE _ GET(RULENAME, 'GRAMMAR);       % DREDGE UP PRODUCTION %

  IF NULL RULE THEN MSG(T,"Can't find production for ",RULENAME,T) 
               ALSO RETURN NIL;

  IF RULE[2] EQ '! THEN RETURN      % HANDLE ALTERNATION (!) %

    BEGIN NEW X;
    1;IF ATOM(RULE[1]) THEN X _ PARSE(RULE[1]) ELSE X _  PARSE1(RULE[1]);
      IF X THEN RETURN <RULENAME, IF ATOM X THEN <X> ELSE X>
                                    % RETURN FIRST SUCCESSFUL ALTERNATE %
      ELSE IF (RULE _ CDDR RULE) EQ NIL         % OTHERWISE BUMP TO NEXT %
              THEN INPUT-STREAM _ SAVED-INPUT-STREAM    % RESTORE LOST TOKENS %
              ALSO RETURN NIL         % AND RETURN NIL IF NONE SUCCESSFUL %
           ELSE GO 1;
    END

  ELSE RETURN IF X _ PARSE1(RULE)        % NO !, PARSE A NORMAL LIST %
                THEN <RULENAME, IF ATOM X THEN <X> ELSE X> 
              ELSE INPUT-STREAM _ SAVED-INPUT-STREAM 
              ALSO NIL;                 % RESTORE ANY LOST TOKENS %

  END;
 
EXPR PARSE1(RULE);              % PASSED THE ACTUAL RULE FROM PARSE %
  BEGIN NEW X,RESULT,Y,SAVED-INPUT-STREAM;

    SAVED-INPUT-STREAM _ INPUT-STREAM;          % SAVE CURRENT POSITION %

    IF RULE EQ NIL THEN RETURN NIL;             % IN CASE OF BUG %

    IF ATOM(RULE)
      THEN              % EITHER ANOTHER RULE OR PUNCTUATION %
        IF RULE EQ INPUT-STREAM[1]
           THEN POP(INPUT-STREAM) ALSO RETURN <RULE>    % EXACT MATCH %
           ELSE IF CAR(AEXPLODEC(RULE)) LT 65 THEN RETURN NIL   % PUNCT %
                ELSE RETURN PARSE(RULE)   % OR RULE NAME %

      ELSE              % MUST BE SOMETHING COMPLICATED %

        IF RULE[1] = '?^         % IS IT A RESERVED WORD? %
          THEN IF RULE[2] EQ INPUT-STREAM[1]    % TRY TO MATCH %
                  THEN POP(INPUT-STREAM) ALSO RETURN <RULE[2]>
                  ELSE RETURN NIL

        ELSE IF RULE[1] EQ '?[            % OPTIONAL PART %
          THEN RETURN IF PARSE1(PRELIST(CDR RULE,LENGTH(RULE)-2)) THENTHAT
                      ELSE <'PLACE-HOLDER>

        ELSE IF RULE[1] EQ '?{            % ZERO OR MORE PART %
          THEN WHILE X _ PARSE1(PRELIST(CDR RULE,LENGTH(RULE)-2))
                 DO: RESULT _ RESULT @ X
          ALSO RETURN IF RESULT THENTHAT ELSE <'PLACE-HOLDER>

        ELSE                    % MUST BE A LIST OF RULES, ALL MUST BE TRUE %
          RETURN
            BEGIN NEW I,RESULT;
            1;I _ CAR RULE;
              IF ATOM I THEN Y _ PARSE(I) ELSE Y _ PARSE1(I);
              IF Y = NIL THEN INPUT-STREAM _ SAVED-INPUT-STREAM 
                         ALSO RETURN NIL        % RESTORE ANY LOST TOKENS %   
              ELSE RESULT _ RESULT @ Y;
              RULE _ CDR RULE;                   
              IF RULE = NIL THEN RETURN RESULT ELSE GO 1;
            END;

  END;

EXPR TPRINT(X,COL);                 % PRETTY PRINT PARSE TREE %
  BEGIN
    IF COL = NIL THEN COL _ 0;
    IF NULL X THEN RETURN ASCII(0)      % DON'T ALLOW NIL TO PRINT ON RETURN %
    ELSE
        FOR NEW I IN X DO:              % PRINT EVERYTHING AT THIS LEVEL %
          IF ATOM I  
            THEN IF I EQ 'PLACE-HOLDER THEN NIL
                 ELSE SPRINT(I, COL+2) 
          ELSE TPRINT(I,COL+2);         % UNLESS IT'S A LIST, THEN INDENT %
  END;

EXPR TOP();
  BEGIN NEW X;
  PROMPT(0);                            % REMOVE PROMPT %
1;MSG(T,"-> ");
  X _ LINEREAD();                       % READ FROM USER %
  IF ATOM X[1]                          % IF ATOM, ASSUME COMMAND %
    THEN 
      (IF X[1] = 'S THEN OLD _ CDR(X)   % SET INPUT-STREAM %
      ELSE IF X[1] = 'E THEN PROMPT(42)
                        ALSO RETURN NIL % EXIT TO LISP %
      ELSE RESET() ALSO TPRINT(PARSE(X[1])))    % PARSE RULE X[1] %
    ELSE
      SPRINT(EVAL(X[1]));               % OTHERWISE ASSUME LISP EXPRESSION %
  GO 1;                                 % EVALUATE AND RETURN ANSWER %
  END;
