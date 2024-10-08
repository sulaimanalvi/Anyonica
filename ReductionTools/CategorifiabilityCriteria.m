(* Mathematica Source File *)
(* Created by the Wolfram Language Plugin for IntelliJ, see http://wlplugin.halirutan.de/ *)
(* :Author: gertvercleyen *)
(* :Date: 2023-03-06 *)

Package["Anyonica`"]


(*
FOR ALL CRITERIA LISTED HERE, SEE:
Classification of Grothendieck rings of complex fusion
categories of multiplicity one up to rank six, Springer.
ZHENGWEI LIU, SEBASTIEN PALCOUX, AND JINSONG WU
*)

(*========================================================================
    COMMUTATIVE SCHUR PRODUCT CRITERION
  ========================================================================
*)
(* Returns value for checking Unitary categorification.
   If the value returned is < 0 the ring can not be
   unitarily categorified. We don't compile the code because
   we use arbitrary precision floating point numbers.
   Note that we require the the first row
	 to consist of the quantum dimensions instead
	 of the first column. Therefore we test for
	 the transposed character table. *)

PackageExport["CSPCValue"]

CSPCValue::usage =
  "CSPCValue[ acc ][ fusionRing ] returns a number that, if lower than 0, indicates that the fusion ring r does not " <>
    "have a unitary categorification. Here acc stands for the accuracy used to approximate the fusion ring characters.";
(*See arXiv:1910.12059v5 for more info.";*)


CSPCValue[acc_][ring_FusionRing] :=
  (
    If[ !CommutativeQ[ring], Message[ CSPCValue::noncommutativering ]; Abort[] ];

    Module[{ chars, r, s },
      chars =
        N[ FusionRingCharacters[ring], { Infinity, acc } ];
      r =
        Rank[ring];

      Catch[
        Do[
          If[
            Re @
              N[
                s = Sum[ chars[[ j1, i ]] chars[[ j2, i ]] chars[[ j3, i ]] / chars[[ 1, i ]], { i, r } ] ,
                { Infinity, acc }
              ] < 0,

            (* THEN *)
            If[ Im[s] == 0, Throw[s] ];
          ],
          { j1, r }, { j2, r }, { j3, r }
        ];
        Infinity
      ]
    ]
  );


(*========================================================================
    PIVOTAL DRINFELD CENTER CRITERION
  ========================================================================
  Returns True if ring has no complex pivotal categorification
*)

(* Note: only works for rings of which we have the characters *)

PackageExport["PDCCriterion"]

PDCCriterion[ ring_FusionRing?CommutativeQ ] :=
  Module[{chars,c},
    chars =
      FusionRingCharacters[ring];
    c =
      #.ConjugateTranspose[#]& /@ chars;

    Catch[
      Do[
        If[
          And @@ Flatten @ AlgebraicIntegerQ[ c[[j]] / c ],
          Throw[ False ]
        ],
        { j, Length[c] }
      ];
      True
    ]

  ];

(*========================================================================
    PSEUDO-UNITARY DRINFELD CENTER CRITERION
  ========================================================================
  Returns True if ring has no complex pseudo-unitary categorification
*)

PackageExport["PUDCC"]

PUDCC[ ring_FusionRing?CommutativeQ ] :=
  With[{ chars = FusionRingCharacters[ring] },
    And @@ Flatten @ AlgebraicIntegerQ[ chars[[1]].ConjugateTranspose[chars[[1]]] / chars ]
  ];


(*========================================================================
    D-NUMBER CRITERION
  ========================================================================
  The function returns true if the fusion ring cannot be categorified.
*)

PackageExport["DNCriterion"]

DNCriterion[ ring_FusionRing?CommutativeQ ] :=
  Module[{ chars, c, DNumberQ, n },
    chars = FusionRingCharacters[ring];
    c = RootReduce[ #.ConjugateTranspose[#]& /@ chars ];

    DNumberQ[ x_ ] :=
      Module[{ p, a, y },
        If[ !AlgebraicIntegerQ[x], Return[ True ] ];

        p =
          MinimalPolynomial[x][y];

        a =
          ( Rest @ MonomialList[p] /. y -> 1 );

        n =
          Exponent[ p, y ];

        And @@
        Table[
          Mod[ a[[i]]^n, a[[-1]]^i ] == 0,
          { i, Length[a] }
        ]
      ];

    Not[ And @@ ( DNumberQ /@ c ) ]

  ];

(*========================================================================
    EXTENDED CYCLOTOMIC CRITERION
  ========================================================================
  The function returns True if the fusion ring cannot be categorified.

  I don't know how to check whether a number is a


*)

ECC[ ring_FusionRing ] :=
  Module[{}
    (* convert matrix to string *)

    (* append string to ECC_DCC_DNC.sage  *)

    (* Evaluate code externally in temporary directory *)

    (* import result *)

  (* interpret result*)
  ]


EvaluateSAGECodeExternally[ sourceCode_String, { source_, exec_, data_ } ] :=
  With[{ dir = CreateDirectory[] },

    ExportSAGECode[ sourceCode, dir, "FileName" -> source ];

    If[
      RunSAGECode[ dir, exec, "FileName" -> data ] != 0,
      Print["ExecutionError"]
    ];

    ImportResultsSAGECode[ dir, data ]
  ];

Options[ExportSAGECode] = { "FileName" -> "source.sage" };
ExportSAGECode[ str_String, dir_String, OptionsPattern[] ] :=
  With[{
    path = FileNameJoin[ { dir, OptionValue[ "FileName" ] } ] },
    Export[ path, str, "Text" ]
  ];


Options[RunSAGECode] = {"FileName" -> "results.txt"};
RunSAGECode[ dir_String, execName_String, OptionsPattern[] ] :=
  With[{
    pathOfExec = FileNameJoin[ { dir, execName } ],
    pathOfOutput = FileNameJoin[ { dir, OptionValue["FileName"] } ]
    },
    Run @
    StringJoin[
      "sage", pathOfExec, " >> ", pathOfOutput
    ]
  ];

ImportResultsSAGECode[ vars_, dir_String, file_String ] :=
  Map[
    Thread[ vars -> # ]&,
    Import[ FileNameJoin[ { dir, file } ] ]
  ];


(*========================================================================
    LAGRANGE CRITERION
  ========================================================================
  The function returns False if the fusion ring cannot be categorified.

*)

PackageExport["LCriterion"]

LCriterion[ ring_FusionRing ] :=
  Module[{ subringDims },
    subringDims =
      FPDim /@
      DeleteDuplicates @
      SubFusionRings[ ring ][[;;,2]];

    Not[And @@ AlgebraicIntegerQ @ RootReduce[ FPDim[ring]/subringDims ]]

  ];


(*========================================================================
    ZERO SPECTRUM CRITERION
  ========================================================================
  The function returns True if the fusion ring cannot be categorified.
*)

PackageExport["ZSCriterion"]

ZSCriterion::usage =
  "ZSCriterion[ fusionRing ] returns True if the fusion ring fusionRing cannot be categorified due to " <>
  "the Zero Spectrum criterion.";

(*See arXiv:2203.06522v1 for more info.";*)

SetAttributes[ ZSC, Listable ];

ZSCriterion[ ring_FusionRing ] :=
  Module[{ mt, non0Cons, ones, d, i1, i2, i3, i4, i5, i6, i7, i8, i9, matches1, matches2, matches3, matches4 },
    mt =
      MT[ring];
    non0Cons =
      NonZeroStructureConstants[ring];
    ones =
      Position[ mt, x_Integer/; x == 1 ];
    d =
      CC[ring] /@ Range[Rank[ring]];

    Catch[
      Do[
        { i2, i1, i3 } = ind;
        matches1 = Cases[ non0Cons, { i4_, i1, i6_ } ];
        Do[
          { i4, i6 } = ind1[[{1,3}]];
          matches2 = Cases[ non0Cons, { i5_, i4, i2 } ];
          Do[
            i5 = ind2[[1]];
            If[
              mt[[ i5, i6, i3 ]] != 0 &&
              MemberQ[ crit1[ {i1,i2,i3,i4,i5,i6}, d, mt ], 1 ],
              matches3 = Cases[ non0Cons, { i7_, i9_, i1 } ];
              Do[
                { i7, i9 } = ind3[[{1,2}]];
                matches4 = Cases[ non0Cons, { i2, i7, i8_ } ];
                Do[
                  i8 = ind4[[3]];
                  If[
                    mt[[ i8, i9, i3 ]] != 0 &&
                    crit3[ { i4, i5, i6, i7, i8, i9 }, d, mt ] == 0 &&
                    MemberQ[ crit2[ { i1, i2, i3, i7, i8, i9 }, d, mt ], 1 ],
                    Throw[ True ]
                  ]
                  ,{ ind4, matches4 }]
                ,{ ind3, matches3 }]
            ]
            ,{ ind2, matches2 }]
          ,{ ind1, matches1 }]
        , { ind, ones } ];
      False
    ]

  ];

crit1 = Compile[ { { i, _Integer, 1 }, { d, _Integer, 1 }, { mt, _Integer, 3 } },
  {
    Sum[ mt[[ i[[5]], i[[4]], k ]] mt[[ i[[3]], d[[ i[[1]] ]], k ]], { k, Length[mt] }],
    Sum[ mt[[ i[[2]], d[[ i[[4]] ]], k ]] mt[[ i[[3]], d[[ i[[6]] ]], k ]], { k, Length[mt] }],
    Sum[ mt[[ d[[ i[[5]] ]], i[[2]], k ]] mt[[ i[[6]], d[[ i[[1]] ]], k ]], { k, Length[mt] }]
  }
];

crit2 = Compile[ { { i, _Integer, 1 }, { d, _Integer, 1 }, { mt, _Integer, 3 } },
  {
    Sum[ mt[[ i[[2]], i[[4]], k ]] mt[[ i[[3]], d[[ i[[6]] ]], k ]], { k, Length[mt] }],
    Sum[ mt[[ i[[5]], d[[ i[[4]] ]], k ]] mt[[ i[[3]], d[[ i[[1]] ]], k ]], { k, Length[mt] }],
    Sum[ mt[[ d[[ i[[2]] ]], i[[5]], k ]] mt[[ i[[1]], d[[ i[[6]] ]], k ]], { k, Length[mt] }]
  }
];

crit3 = Compile[ { { i, _Integer, 1 }, { d, _Integer, 1 }, { mt, _Integer, 3 } },
  Sum[ mt[[ i[[1]], i[[4]], k ]] mt[[ d[[ i[[2]] ]], i[[5]], k ]] mt[[ i[[3]], d[[ i[[6]] ]], k ]], { k, Length[mt] }]
];
