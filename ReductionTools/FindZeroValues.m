(* ::Package:: *)

Package["Anyonica`"]

(*
+---------------------------------------------------------------------------+
|                                                                           |
|                             FINDING 0-VALUES                              |
|                                                                           |
+---------------------------------------------------------------------------+
*)

PackageExport["FindZeroValues"]

FindZeroValues::usage =
  "Returns a list of all possible configurations of zero values of vars, consistent with the rational equations eqns";

FindZeroValues::wrongequationsformat =
  "`1` must be a list of equations/inequalities.";

FindZeroValues::wrongvariablesformat =
  "`1` must be a list of variables of the form _Symbol[i__Integer].";

Options[ FindZeroValues ] :=
  Join[
    {
      "FindZerosBy" -> "CCode"
    },
    Options[BooleanZeroValues]
  ];

CheckArgs[ eqns_, vars_ ] :=
  Which[
    !ListQ[eqns]
    ,
    Message[ FindZeroValues::wrongequationsformat, eqns ];
    Abort[]
    ,
    !ListQ[vars]
    ,
    Message[ FindZeroValues::wrongvariablesformat, vars ];
    Abort[]
  ];

FindZeroValues[ eqns_, vars_, opts:OptionsPattern[] ] :=
(
  CheckArgs[eqns, vars];
  If[
    OptionValue["FindZerosBy"] === "CCode"
    ,
    Module[
      {
        regMats, simpleEqns, simpleVars, revertVars, simpleMats, s, procID,
        reducedEqns, result, absTime, proposition, knowns, equivs, reducedVars, AddEquivalences
      },

      procID =
      ToString[Unique[]];

      printlog["FZV:init", {procID, eqns, vars, {opts}}];

      { absTime, result } =
      AbsoluteTiming[
        regMats =
          OptionValue["InvertibleMatrices"];

        { { simpleEqns, simpleMats }, simpleVars, revertVars } =
          SimplifyVariables[ { eqns, regMats }, vars, s ];

        (* Convert and reduce the equations using logic *)
        { proposition, knowns, equivs } =
          MapAt[
            BooleanConvert[#, "CNF"]&,
            ReduceViaLogic[
              BinEqnsToProposition[simpleEqns] && MatsToProposition[simpleMats],
              s
            ],
            {1}
          ];

        reducedEqns =
          PropToEqns @ proposition;

        reducedVars =
          Complement[ simpleVars, knowns[[;;,1]], equivs[[;;,1]] ];

        If[ (* If all variables are known *)
          Length[ reducedVars ] === 0
          , (* THEN: select all vars that point to False, replace False by 0 and return solution *)
          Return[ { Select[ equivs, Not @* Extract[2] ] /. False -> 0 } ]
        ];

        AddEquivalences[ sol_ ] :=
          SortBy[First] @
          Select[ #[[2]] === 0& ] @
          Join[
            sol,
            equivs /. Dispatch[sol] /. False -> 0
          ];

        Map[
          AddEquivalences,
          SolveDiophantineSystem[ reducedEqns, reducedVars, { 0, 1 } ]
        ] /. revertVars
      ];

      (*      printlog["FZV:solutions", {procID,result}];*)

      printlog["Gen:results", {procID, result, absTime}];

      result
    ]
    ,
    AddOptions[opts][BooleanZeroValues][ eqns, vars ]
  ]
);


PropToEqns[ prop_And ] :=
  Map[
    Simplify,
    ( List @@ prop ) /. HoldPattern[Or[x__]] :> ( Plus[x] >= 1 ) /. Not[a_] :> (1 - a)/.Equivalent->Equal
  ];

PropToEqns[ prop_Or ] :=
  Map[
    Simplify,
    { prop } /. HoldPattern[Or[x__]] :> ( Plus[x] >= 1 ) /. Not[a_] :> (1 - a)/.Equivalent->Equal
  ];

PropToEqns[ True ] :=
  { True };

PropToEqns[ False ] :=
  { False };

PackageExport["BinEqnsToProposition"]

BinEqnsToProposition[ eqns_ ] :=
  And @@ (
    Equivalent @@@
    Map[
      IntToBool,
      Join @@@ MonomialList[ List @@@ DeleteCases[True] @ ReduceMonomials @ eqns ] /.
      Times -> And,
      {2}
    ]
  );

IntToBool[1] :=
  True;

IntToBool[0] :=
  False;

IntToBool[x_] :=
  x;

PackageExport["BooleanZeroValues"]

BooleanZeroValues::usage =
  "BooleanZeroValues[binEqns,vars] tries to find admissible sets of 0 values for the variables vars using logic.";

BooleanZeroValues::mallocfailure =
  "From SatfisfiabilityInstances: Not enough free memory to perform computation.";

Options[BooleanZeroValues] :=
  Join[
    {
      "InvertibleMatrices" -> { }
    },
    Options[SatisfiabilityInstances]
  ];

BooleanZeroValues[ eqns_, vars_, opts:OptionsPattern[] ] :=
  Module[
    { regMats, trueVars, newEqns, newRegMats, newVars, revertVars, x, equivs, remainingVars,
      AddEquivalences, proposition, instances, booleanQ, knowns
    },

    booleanQ[x_] :=
      MatchQ[x, _ -> (True|False)];

    regMats =
      Normal @ OptionValue["InvertibleMatrices"];

    If[
      MemberQ[ PermanentConditions @ regMats, False ] || vars === {},
      Return[ { } ]
    ];

    trueVars =
      Cases[ regMats, {{a_}} /; a =!= 0 :> a ];

    regMats =
      regMats ~ WithMinimumDimension ~ 2;

    If[
      Length[trueVars] == Length[vars],
      Return[ { { } } ]
    ];

    { { newEqns, newRegMats }, newVars, revertVars } =
      SimplifyVariables[
        {
          eqns/.Dispatch[ Thread[ trueVars -> 1 ] ],
          regMats ~ WithMinimumDimension ~ 2
        },
        Complement[ vars, trueVars ],
        x
      ];

    { proposition, knowns, equivs } =
      ReduceViaLogic[
        BinEqnsToProposition[newEqns] && MatsToProposition[newRegMats],
        x
      ];

    remainingVars =
      Complement[ newVars, knowns[[;;,1]], equivs[[;;,1]] ];

    instances =
      Catch[
        Thread[ remainingVars -> # ]& /@
        AddOptions[opts][SatisfiabilityInstances][
          BooleanMinimize @ proposition,
          remainingVars,
          All
        ]
      ];

    If[
      !MatchQ[ instances, { { __?booleanQ }.. } ]
      ,
      Message[BooleanZeroValues::mallocfailure]; Abort[]
    ];

    (* Add the variables from the equivalences that are False *)
    AddEquivalences[ sol_ ] :=
      SortBy[First] @
      Select[ Not @* Extract[2] ] @
      Join[ sol, equivs/.Dispatch[sol] ];

    Map[ AddEquivalences, instances ]/. revertVars /. False -> 0
  ];


(* Assumes single indexed vars x[i] *)
PackageExport["ReduceViaLogic"]

ReduceViaLogic[ proposition_, x_ ] :=
  Module[
    { UpdateKnowns, UpdateEquivalences, SimplifySystem, simplify1, simplify2, simplify3, simplify4, findEquiv },

    UpdateKnowns[ { prop_, knowns_, equivs_ } ] :=
      With[{ newKnowns = Cases[ prop, x[i_] :> ( x[i] -> True ) ] },
        {
          prop/.Dispatch[newKnowns],
          Join[ knowns, newKnowns ],
          equivs/.Dispatch[newKnowns]
        }
      ];

    findEquiv[ prop_ ] :=
      FirstCase[
        prop,
        ( Equivalent[ x[i_], y__ ] | Equivalent[ y__, x[i_] ] ) /; FreeQ[ y, x[i] ] :> ( x[i] -> y )
      ];

    UpdateEquivalences[ { prop_, knowns_, equivs_ } ] :=
      Module[ { newEquivs, newProp, eq },
        newProp =
          prop;
        newEquivs =
          equivs;

        While[
          !MissingQ[ eq = findEquiv @ newProp ]
          ,
          newEquivs =
            Join[ newEquivs/.eq, {eq} ];

          newProp =
            newProp/.eq
        ];

        { newProp, knowns, newEquivs }
      ];


    SimplifySystem[ { prop_, knowns_, equivs_ } ] :=
      If[
        TrueQ @ prop
        ,
        { prop, knowns, equivs }
        ,
        {
          DeleteDuplicatesBy[
            prop /. { And -> Union @* And, Or -> Union @* Or },
            Sort
          ],
          Join[ knowns, Select[TrueQ @* Extract[2] ] @ equivs ],
          Select[ Not @* TrueQ @* Extract[2] ] @ equivs
        }
      ];

    simplify1 =
      FixedPoint[ SimplifySystem @* UpdateEquivalences @* UpdateKnowns, # ]&;

    simplify2 = (* Converting to CNF often gives extra info about variables *)
      FixedPoint[ UpdateKnowns, { BooleanConvert[ #[[1]], "CNF" ], #[[2]], #[[3]] } ]&;

    simplify3 = (* Converting back to "DNF" can reduce the number of variables as well *)
      With[
        { dnfForm = BooleanConvert[ #[[1]], "DNF" ] },
        { removeRedundantVars = Dispatch[ Thread[ (List @@ Intersection @@ dnfForm) -> True ] ] },
        {
          dnfForm /. removeRedundantVars,
          #[[2]],
          #[[3]] /. removeRedundantVars
        }
      ]&;

    simplify4 = (* Often some equivalences remain but UpdateEquivalences doesn't work on "DNF"/"CNF" forms so we revert *)
      simplify1 @
      {
        ReplaceRepeated[
          BooleanConvert[#[[1]],"CNF"],
          And[p1___, (! a_ || b_), (a_ || ! b_), p2___] :> And[ p1, Equivalent[ a, b ], p2 ]
        ],
        #[[2]],
        #[[3]]
      }&;

      { proposition, { }, { } } //
      simplify1 //
      simplify2 //
      simplify3 //
      simplify4
  ];

PackageExport["MatsToProposition"]

MatsToProposition[ matList_ ] :=
  With[{ perms = ReduceMonomials @* Permanent /@ matList },
    And @@ ReplaceAll[ perms, { Times -> And, Plus -> Or } ]
  ];


ReduceMonomials[ expr_ ] :=
  expr //
  ReplaceAll[ Power[ a_, b_Integer ] :> a ] //
  ReplaceAll[ Times[ a_Integer, b__ ] :> Times[b] ];


PermanentConditions[ mats_List ] :=
  Map[
    ( Expand[Permanent[#]] != 0 )&,
    mats
  ];


PropositionToCNFFile[ prop_, x_ ] :=
  With[{
    orProps = List @@ BooleanConvert[ prop, "CNF" ],
    nVars = CountVariables[ prop, x ]
    },
    StringJoin[
      "p "<>ToString[nVars] <> " " <> ToString[ Length @ orProps ] <>"\n",
      Sequence @@ Map[ OrToString[x], orProps ]
    ]
  ];


OrToString[ x_][x[i_]] :=
  ToString[i] <> " 0";

OrToString[ x_][Not[x[i_]]] :=
  ToString[-i] <> " 0";

OrToString[ x_ ][ prop_ ] :=
  StringJoin[ #, " 0\n" ]& @
  StringRiffle @
  ReplaceAll[ prop, { Or -> List, x[i_] :> ToString[i], Not[x[i_]] :> ToString[-i] } ];
