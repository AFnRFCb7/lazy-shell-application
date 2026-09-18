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
                                    mounts ,
                                    name ,
                                    runtime-inputs ,
                                    teardown ,
                                    text
                                } :
                                    let
                                        implementation-parameters =
                                            {
                                                mounts = mounts ;
                                                name = name ;
                                                runtime-inputs = runtime-inputs ;
                                                teardown = teardown ;
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
                                                                            builtins.concatLists
                                                                                [
                                                                                    [
                                                                                        "--ro-bind" "$INPUT" "/input.json"
                                                                                        "--bind" "$OUTPUT" "/output.json"
                                                                                        "--tmpfs" "/private/standard"
                                                                                        "--tmpfs" "/scratch"
                                                                                    ]
#                                                                                    (
#                                                                                        builtins.attrValues
#                                                                                            (
#                                                                                                let
#                                                                                                    mapper =
#                                                                                                        name : { source ? null , type } :
#                                                                                                            if type == "bind" then [ "--bind" source "/mounts/${ name }" ]
#                                                                                                            else if type == "ro-bind" then [ "--ro-bind" source "/mounts/${ name }" ]
#                                                                                                            else if type == "tmp" then [ "--tmpfs" "/mounts/${ name }" ]
#                                                                                                            else builtins.throw "unsupported type ${ type }" ;
#                                                                                                    in builtins.concatLists ( builtins.mapAttrs mapper implementation-parameters.mounts )
#                                                                                            )
#                                                                                    )
                                                                                ] ;
                                                                        name = "application" ;
                                                                        runScript = "application" ;
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
                                                                                                        mapfile -t ARGUMENTS < <(
                                                                                                            jq --raw-output '.arguments[]' /input.json
                                                                                                        )
                                                                                                        if jq --exit-status 'has("inputs") and (.inputs | has("standard"))' /input.json > /dev/null
                                                                                                        then
                                                                                                            STANDARD_INPUT="$( jq --raw-output '.inputs.standard' /input.json )" || failure 7828132754944749
                                                                                                            if application "${ builtins.concatStringsSep "" [ "$" "{" "ARGUMENTS[@]" "}" ] }" <<< "$STANDARD_INPUT" > /private/standard-output 2> /private/standard-error
                                                                                                            then
                                                                                                                STATUS="$?"
                                                                                                            else
                                                                                                                STATUS="$?"
                                                                                                            fi
                                                                                                        else
                                                                                                            if application "${ builtins.concatStringsSep "" [ "$" "{" "ARGUMENTS[@]" "}" ] }" > /private/standard-output 2> /private/standard-error
                                                                                                            then
                                                                                                                STATUS="$?"
                                                                                                            else
                                                                                                                STATUS="$?"
                                                                                                            fi
                                                                                                        fi
                                                                                                        jq \
                                                                                                            --null-input \
                                                                                                            --rawfile STANDARD_ERROR /private/standard-error \
                                                                                                            --rawfile STANDARD_OUTPUT /private/standard-output \
                                                                                                            --argjson STATUS "$STATUS" \
                                                                                                            '{
                                                                                                                "standard-error" : $STANDARD_ERROR ,
                                                                                                                "standard-output" : $STANDARD_OUTPUT ,
                                                                                                                "status" : $STATUS
                                                                                                            }' > /output.json
                                                                                                    '' ;
                                                                                            }
                                                                                    )
                                                                                ] ;
                                                                    }
                                                            )
                                                            (
                                                                root-parameters.writeShellApplication
                                                                    {
                                                                        name = "cleanup" ;
                                                                        runtimeInputs = [ coreutils nix ] ;
                                                                        text =
                                                                            if implementation-parameters.teardown then
                                                                                ''
                                                                                    rm --force "$INPUT" "$OUTPUT"
                                                                                    # nohup nice adjustment 19 nix-collect-garbage --max-jobs 1 --cores 1 &
                                                                                ''
                                                                            else
                                                                                ''
                                                                                    rm --force "$INPUT" "$OUTPUT"
                                                                                '' ;
                                                                    }
                                                            )
                                                        ] ;
                                                    text =
                                                        ''
                                                            INPUT="$( mktemp --suffix ".json" )" || failure 7258549447146326
                                                            export INPUT
                                                            OUTPUT="$( mktemp --suffix ".json" )" || failure 7151471466863861
                                                            export OUTPUT
                                                            trap cleanup EXIT
                                                            if [[ -t 0 ]]
                                                            then
                                                                STANDARD_INPUT="$( cat )" || exit 198 # failure 6712938899436674
                                                                jq \
                                                                    --null-input \
                                                                    --arg STANDARD_INPUT "$STANDARD_INPUT" \
                                                                    --args \
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
                                                                    --args \
                                                                    '{
                                                                        "arguments" : $ARGS.positional
                                                                    }' -- "$@" > "$INPUT"
                                                            fi
                                                            application
                                                            STANDARD_ERROR="$( jq --raw-output '.["standard-error"]' "$OUTPUT" )" || failure 8856851932761746
                                                            echo -n "$STANDARD_ERROR" >&2
                                                            STANDARD_OUTPUT="$( jq --raw-output '.["standard-output"]' "$OUTPUT" )" || failure 9396616715561937
                                                            echo -n "$STANDARD_OUTPUT"
                                                            STATUS="$( jq --raw-output '.["status"]' "$OUTPUT" )" || failure 9357282994784138
                                                            exit "$STATUS"
                                                        '' ;
                                                } ;
                            root-parameters =
                                {
                                    buildFHSUserEnv = buildFHSUserEnv ;
                                    coreutils = coreutils ;
                                    failure = failure 3885643131463398 ;
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
                                            mounts ,
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
                                                        mounts = mounts ;
                                                        nixosTest = nixosTest ;
                                                        name = name ;
                                                        nodes = nodes ;
                                                        order = order ;
                                                        runtime-inputs = runtime-inputs ;
                                                        standard-error = visitor { string = path : value : builtins.toFile "standard-error" value ; } standard-error ;
                                                        standard-input = visitor { null = path : value : value ; string = path : value : builtins.toFile "standard-input" value ; } standard-input ;
                                                        standard-output = visitor { string = path : value : builtins.toFile "standard-error" value ; } standard-output ;
                                                        status = visitor { int = path : value : builtins.toString value ; } status ;
                                                        test-setup = visitor { string = path : value : value ; } test-setup ;
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
                                                                    runtimeInputs = [ check-parameters.coreutils check-parameters.findutils ( root-parameters.failure ) ] ;
                                                                    text =
                                                                        ''
                                                                            mkdir --parents /tmp/expected
                                                                            ln --symbolic ${ check-parameters.standard-error } /tmp/expected/standard-error
                                                                            ln --symbolic ${ check-parameters.standard-output } /tmp/expected/standard-output
                                                                            echo -n ${ check-parameters.status } > /tmp/expected/status
                                                                            mkdir --parents /tmp/observed
                                                                            exec 0<&-
                                                                            if ${ implementation { name = check-parameters.name ; mounts = check-parameters.mounts ; runtime-inputs = check-parameters.runtime-inputs ; teardown = false ; text = check-parameters.text ; } }/bin/${ check-parameters.name } ${ builtins.concatStringsSep " " check-parameters.arguments } ${ if builtins.typeOf check-parameters.standard-input == "null" then "" else "< ${ check-parameters.standard-input }" } > /tmp/observed/standard-output 2> /tmp/observed/standard-error
                                                                            then
                                                                                echo -n "$?" > /tmp/observed/status
                                                                            else
                                                                                echo -n "$?" > /tmp/observed/status
                                                                            fi
                                                                            if ! diff --recursive --unified /tmp/expected /tmp/observed
                                                                            then
                                                                                if true ; then echo 1723258852938545 1753772616956527 >&2 && exit 104 ; fi
                                                                                failure 1145694589525674
                                                                            fi
                                                                        '' ;
                                                                } ;
                                                        in ''${ check-parameters.client }.succeed("${ test-script }/bin/test-script")'' ;
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