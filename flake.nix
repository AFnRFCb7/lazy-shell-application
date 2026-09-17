{
    inputs = { } ;
    outputs =
        { self } :
            {
                lib =
                    let
                        implementation =
                            { buildFHSUserEnv , coreutils , jq , nix , writeShellApplication } : { name , runtime-inputs , text } :
                                let
                                    parameters =
                                        {
                                            buildFHSUserEnv = buildFHSUserEnv ;
                                            coreutils = coreutils ;
                                            jq = jq ;
                                            nix = nix ;
                                            runtime-inputs = runtime-inputs ;
                                            text = text ;
                                            writeShellApplication = writeShellApplication ;
                                        } ;
                                    in
                                        parameters.writeShellApplication
                                            {
                                                name = name ;
                                                runtimeInputs =
                                                    [
                                                        parameters.coreutils
                                                        parameters.jq
                                                        parameters.nix
                                                        (
                                                            parameters.buildFHSUserEnv
                                                                {
                                                                    extraBwrapArgs =
                                                                        [
                                                                            "--ro-bind" "$INPUT" "/input"
                                                                            "--bind" "$OUTPUT" "/output"
                                                                            "--tmpfs" "/private/standard-error"
                                                                            "--tmpfs" "/private/standard-output"
                                                                            "--tmpfs" "/private/status"
                                                                            "--tmpfs" "/scratch"
                                                                        ] ;
                                                                    name = "application" ;
                                                                    targetPkgs =
                                                                        pkgs :
                                                                            [
                                                                                (
                                                                                    pkgs.writeShellApplication
                                                                                        {
                                                                                            name = "application" ;
                                                                                            runtimeInputs =
                                                                                                [
                                                                                                    pkgs.coreutils
                                                                                                    pkgs.jq
                                                                                                    (
                                                                                                        pkgs.writeShellApplication
                                                                                                            {
                                                                                                                name = "application" ;
                                                                                                                runtimeInputs = parameters.runtime-inputs pkgs ;
                                                                                                                text = parameters.text ;
                                                                                                            }
                                                                                                    )
                                                                                                ] ;
                                                                                            text =
                                                                                                ''
                                                                                                    if application > /private/standard-input 2> /private/standard-error
                                                                                                    then
                                                                                                        echo "$?" /private/status
                                                                                                    else
                                                                                                        echo "$?" /private/status
                                                                                                    fi
                                                                                                    jq \
                                                                                                        --null-input \
                                                                                                        --rawfile STANDARD_ERROR /private/standard-error \
                                                                                                        --rawfile STANDARD_OUTPUT /private/standard-output \
                                                                                                        --rawfile STATUS /private/status \
                                                                                                        '{
                                                                                                            "standard-error" : $STANDARD_ERROR ,
                                                                                                            "standard-output" : $STANDARD_OUTPUT ,
                                                                                                            "status" : $STATUS
                                                                                                        }' > "$OUTPUT"
                                                                                                '' ;
                                                                                        }
                                                                                )
                                                                            ] ;
                                                                }
                                                        )
                                                    ] ;
                                                text =
                                                    ''
                                                        DEFAULT_STANDARD_ERROR=""
                                                        DEFAULT_STANDARD_OUTPUT=""
                                                        DEFAULT_STATUS=0
                                                        while [[ "$#" -gt 0 ]]
                                                        do
                                                            case "$1" in
                                                                --default-standard-error)
                                                                    DEFAULT_STANDARD_ERROR="$2"
                                                                    shift 2
                                                                    ;;
                                                                --default-standard-output)
                                                                    DEFAULT_STANDARD_OUTPUT="$2"
                                                                    shift 2
                                                                    ;;
                                                                --default-status)
                                                                    DEFAULT_STATUS="$2"
                                                                    shift 2
                                                                    ;;
                                                                *)
                                                                    exit 156
                                                                    ;;
                                                            esac
                                                        done
                                                        INPUT="$( mktemp --suffix ".json" )" || exit 182
                                                        export INPUT
                                                        OUTPUT="$( mktemp --suffix ".json" )" || exit 121
                                                        export OUTPUT
                                                        cleanup ( ) {
                                                            rm --force "$INPUT" "$OUTPUT"
                                                            nohup nice adjustment 19 nix-collect-garbage --max-jobs 1 --cores 1 &
                                                        }
                                                        trap cleanup EXIT
                                                        if [[ -t 0 ]]
                                                        then
                                                            STANDARD_INPUT="$( cat )" || exit 121
                                                            jq \
                                                                --null-input \
                                                                --arg STANDARD_INPUT "$STANDARD_INPUT" \
                                                                '{
                                                                    "arguments" : $ARGS.positional ,
                                                                    "inputs" :
                                                                        {
                                                                            "standard" : $STANDARD_INPUT
                                                                        }
                                                                }' -- "$@" > "$INPUT"
                                                        else
                                                            jq \
                                                                --null-input \
                                                                '{
                                                                    "arguments" : $ARGS.positional
                                                                }' -- "$@" > "$IbindfsNPUT"
                                                        fi
                                                        application
                                                        STANDARD_ERROR="$( jq --arg DEFAULT_STANDARD_ERROR "$DEFAULT_STANDARD_ERROR" --raw-output '.["standard-error"] // $DEFAULT_STANDARD_ERROR' "$OUTPUT" )" || exit 116
                                                        echo -n "$STANDARD_ERROR" >&2
                                                        STANDARD_OUTPUT="$( jq --arg DEFAULT_STANDARD_OUTPUT "$DEFAULT_STANDARD_OUTPUT" --raw-output '.["standard-output"] // $DEFAULT_STANDARD_OUTPUT' "$OUTPUT" )" || exit 121
                                                        echo -n "$STANDARD_OUTPUT"
                                                        STATUS="$( jq --arg DEFAULT_STATUS "$DEFAULT_STATUS" --raw-output '.["status"] // $DEFAULT_STATUS' "$OUTPUT" )" || exit 118
                                                        exit "$STATUS"
                                                    '' ;
                                            } ;
                        in
                            {
                                check =
                                    { arguments , client , nixosTest , nodes , order , standard-error , standard-input , standard-output , status , test-setup } :
                                        let
                                            parameters =
                                                {
                                                    arguments = arguments ;
                                                    client = client ;
                                                    nixosTest = nixosTest ;
                                                    nodes = nodes ;
                                                    order = order ;
                                                    standard-input = standard-input ;
                                                    test-setup = test-setup ;
                                                } ;
                                            nixos-test =
                                                parameters.nixosTest
                                                    {
                                                        name = "nixos-test" ;
                                                        nodes = parameters.nodes ;
                                                        testScript = builtins.concatStringsSep "/n" ( builtins.concatLists [ parameters.test-setup ] ) ;
                                                    } ;
                                            test =
                                                let
                                                    test-script =
                                                        ''
                                                            mkdir --parents /tmp/expected
                                                            ln --symbolic ${ builtins.toFile "standard-error" parameters.standard-error } /tmp/expected/standard-error
                                                            ln --symbolic ${ builtins.toFile "standard-output" parameters.standard-output } /tmp/expected/standard-output
                                                            ln --symbolic ${ builtins.toFile "status" parameters.status } /tmp/expected/status
                                                            mkdir --parents /tmp/observed
                                                            if ${ implementation } ${ builtins.concatStringsSep "" [ parameters.arguments ] } ${ if builtins.typeOf parameters.standard-input == "null" then "" else "< ${ builtins.toFile "standard-input" parameters.standard-input }" } > /tmp/observed/standard-output 2> /tmp/observed/standard-error
                                                            then
                                                                echo "$?" > /tmp/observed/status
                                                            else
                                                                echo "$?" > /tmp/observed/status
                                                            fi
                                                            if ! diff --unified /tmp/expected /tmp/observed then
                                                                exit 143
                                                            fi
                                                        '' ;
                                                    in ''${ client }.success("test-script")'' ;
                                            in
                                                {
                                                    name = builtins.concatStringsSep "-" [ "order" ( builtins.toString order ) ] ;
                                                    order = order ;
                                                    test = nixos-test ;
                                                } ;
                                implementation = implementation ;
                            } ;
            } ;
}