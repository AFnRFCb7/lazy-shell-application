{
    inputs = { } ;
    outputs =
        { self } :
            {
                lib =
                    {
                        buildFHSUserEnv ,
                        coreutils ,
                        failure ,
                        jq ,
                        nix ,
                        visitor ,
                        writeShellApplication
                    } :
                        let
                            implementation =
                                {
                                    name ,
                                    runtime-inputs ,
                                    text
                                } :
                                    let
                                        implementation-parameters =
                                            {
                                                name = name ;
                                                runtime-inputs = runtime-inputs ;
                                                text = text ;
                                            } ;
                                        in
                                            root-parameters.writeShellApplication
                                                {
                                                    name = implementation-parameters.name ;
                                                    runtimeInputs =
                                                        [
                                                            root-parameters.coreutils
                                                            root-parameters.failure
                                                            root-parameters.jq
                                                            root-parameters.nix
                                                            (
                                                                root-parameters.buildFHSUserEnv
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
                                                                                                                    runtimeInputs = implementation-parameters.runtime-inputs pkgs ;
                                                                                                                    text = implementation-parameters.text ;
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
                                                                        failure 4512848497123333
                                                                        ;;
                                                                esac
                                                            done
                                                            INPUT="$( mktemp --suffix ".json" )" || failure 7258549447146326
                                                            export INPUT
                                                            OUTPUT="$( mktemp --suffix ".json" )" || failure 7151471466863861
                                                            export OUTPUT
                                                            cleanup ( ) {
                                                                rm --force "$INPUT" "$OUTPUT"
                                                                nohup nice adjustment 19 nix-collect-garbage --max-jobs 1 --cores 1 &
                                                            }
                                                            trap cleanup EXIT
                                                            if [[ -t 0 ]]
                                                            then
                                                                STANDARD_INPUT="$( cat )" || failure 6712938899436674
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
                                                            STANDARD_ERROR="$( jq --arg DEFAULT_STANDARD_ERROR "$DEFAULT_STANDARD_ERROR" --raw-output '.["standard-error"] // $DEFAULT_STANDARD_ERROR' "$OUTPUT" )" || failure 8856851932761746
                                                            echo -n "$STANDARD_ERROR" >&2
                                                            STANDARD_OUTPUT="$( jq --arg DEFAULT_STANDARD_OUTPUT "$DEFAULT_STANDARD_OUTPUT" --raw-output '.["standard-output"] // $DEFAULT_STANDARD_OUTPUT' "$OUTPUT" )" || failure 9396616715561937
                                                            echo -n "$STANDARD_OUTPUT"
                                                            STATUS="$( jq --arg DEFAULT_STATUS "$DEFAULT_STATUS" --raw-output '.["status"] // $DEFAULT_STATUS' "$OUTPUT" )" || failure 9357282994784138
                                                            exit "$STATUS"
                                                        '' ;
                                                } ;
                            root-parameters =
                                {
                                    buildFHSUserEnv = buildFHSUserEnv ;
                                    coreutils = coreutils ;
                                    failure = failure ;
                                    jq = jq ;
                                    nix = nix ;
                                    visitor = visitor ;
                                    writeShellApplication = writeShellApplication ;
                                } ;
                            in
                                {
                                    check =
                                        {
                                            client ,
                                            coreutils ,
                                            findutils ,
                                            nixosTest ,
                                            nodes ,
                                            order ,
                                            test-setup ,
                                            writeShellApplication
                                        } :
                                        {
                                            name ,
                                            runtime-inputs ,
                                            text
                                        } :
                                        {
                                            arguments ?  [ ] ,
                                            standard-error ? "" ,
                                            standard-input ? null ,
                                            standard-output ? "" ,
                                            status ? 0
                                        } :
                                            let
                                                check-parameters =
                                                    {
                                                        arguments = visitor { string = path : value : value ; } arguments ;
                                                        client = client ;
                                                        coreutils = coreutils ;
                                                        findutils = findutils ;
                                                        nixosTest = nixosTest ;
                                                        name = name ;
                                                        nodes = nodes ;
                                                        order = order ;
                                                        runtime-inputs = runtime-inputs ;
                                                        standard-error = visitor { string = path : value : builtins.toFile "standard-error" value ; } standard-error ;
                                                        standard-input = visitor { null = path : value : value ; string = path : value : builtins.toFile "standard-input" value ; } standard-input ;
                                                        standard-output = visitor { string = path : value : builtins.toFile "standard-error" value ; } standard-output ;
                                                        status = visitor { int = path : value : builtins.toString value ; } status ;
                                                        test-setup = test-setup ;
                                                        text = text ;
                                                        writeShellApplication = writeShellApplication ;
                                                    } ;
                                                nixos-test =
                                                    check-parameters.nixosTest
                                                        {
                                                            name = "nixos-test" ;
                                                            nodes = check-parameters.nodes ;
                                                            testScript = builtins.concatStringsSep "/n" ( builtins.concatLists [ check-parameters.test-setup [ test ] ] ) ;
                                                        } ;
                                                test =
                                                    let
                                                        test-script =
                                                            writeShellApplication
                                                                {
                                                                    name = "test-script" ;
                                                                    runtimeInputs = [ coreutils findutils ] ;
                                                                    text =
                                                                        ''
                                                                            mkdir --parents /tmp/expected
                                                                            ln --symbolic ${ check-parameters.standard-error } /tmp/expected/standard-error
                                                                            ln --symbolic ${ check-parameters.standard-output } /tmp/expected/standard-output
                                                                            echo ${ check-parameters.status } /tmp/expected/status
                                                                            mkdir --parents /tmp/observed
                                                                            if ${ implementation { name = check-parameters.name ; runtime-inputs = check-parameters.runtime-inputs ; text = check-parameters.text ; } }/bin/${ check-parameters.name } ${ builtins.concatStringsSep "" check-parameters.arguments } ${ if builtins.typeOf check-parameters.standard-input == "null" then "" else "< ${ check-parameters.standard-input }" } > /tmp/observed/standard-output 2> /tmp/observed/standard-error
                                                                            then
                                                                                echo "$?" > /tmp/observed/status
                                                                            else
                                                                                echo "$?" > /tmp/observed/status
                                                                            fi
                                                                            if ! diff --unified /tmp/expected /tmp/observed then
                                                                                failure 1145694589525674
                                                                            fi
                                                                        '' ;
                                                                } ;
                                                        in ''${ check-parameters.client }.success("test-script")'' ;
                                                in
                                                    {
                                                        name = builtins.concatStringsSep "-" [ "check" ( builtins.toString order ) ] ;
                                                        order = order ;
                                                        value = dependencies : nixos-test ;
                                                    } ;
                                    implementation = implementation ;
                                } ;
            } ;
}