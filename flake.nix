{
    inputs = { } ;
    outputs =
        { self } :
            {
                lib =
                    {
                        config-identity ? x : x ,
                        lib-identity ? x : x ,
                        options-identity ? x : x ,
                        pkgs-identity ? x : x
                    } :
                        let
                            implementation =
                                { config , lib , pkgs , ... } :
                                    let
                                        _config = config-identity config ;
                                        _lib = lib-identity lib ;
                                        _pkgs = pkgs-identity pkgs ;
                                        in
                                            {
                                                options =
                                                    options-identity
                                                        {
                                                            lazy-shell-application =
                                                                _lib.mkOption
                                                                    {
                                                                        default =
                                                                            {
                                                                                mounts ,
                                                                                name ,
                                                                                post ,
                                                                                runtime-inputs ,
                                                                                text
                                                                            } :
                                                                                let
                                                                                    parameters =
                                                                                        {
                                                                                            mounts = mounts ;
                                                                                            name =
                                                                                                if name == "test" then builtins.throw "test is not a good name"
                                                                                                else name ;
                                                                                            post = post ;
                                                                                            runtime-inputs = runtime-inputs ;
                                                                                            text = text ;
                                                                                        } ;
                                                                                    in
                                                                                        _pkgs.writeShellApplication
                                                                                            {
                                                                                                name = parameters.name ;
                                                                                                runtimeInputs =
                                                                                                    [
                                                                                                        ( _config.failure { } )
                                                                                                        _pkgs.coreutils
                                                                                                        _pkgs.jq
                                                                                                        (
                                                                                                            _pkgs.writeShellApplication
                                                                                                                {
                                                                                                                    name = "cleanup" ;
                                                                                                                    runtimeInputs = [ _pkgs.coreutils ] ;
                                                                                                                    text =
                                                                                                                        config.visitor
                                                                                                                            { }
                                                                                                                            {
                                                                                                                                null =
                                                                                                                                    path : value :
                                                                                                                                        ''
                                                                                                                                            rm --force "$INPUT_FILE" "$OUTPUT_FILE"
                                                                                                                                        '' ;
                                                                                                                                string =
                                                                                                                                    path : value :
                                                                                                                                        ''
                                                                                                                                            nohup nice --adjustment 19 "${ value }"
                                                                                                                                            rm --force "$INPUT_FILE" "$OUTPUT_FILE"
                                                                                                                                        '' ;
                                                                                                                            }
                                                                                                                            post ;
                                                                                                                }
                                                                                                        )
                                                                                                        (
                                                                                                            _pkgs.buildFHSUserEnv
                                                                                                                {
                                                                                                                    extraBwrapArgs =
                                                                                                                        builtins.concatLists
                                                                                                                            [
                                                                                                                                [
                                                                                                                                    "--ro-bind" "$INPUT_FILE" "/input"
                                                                                                                                ]
                                                                                                                                (
                                                                                                                                    let
                                                                                                                                        mapper =
                                                                                                                                            name : { source ? null , type } :
                                                                                                                                                if type == "bind" then [ "--bind" source "/mounts/${ name }" ]
                                                                                                                                                else if type == "ro-bind" then [ "--ro-bind" source "/mounts/${ name }" ]
                                                                                                                                                else if type == "tmp" then [ "--tmpfs" "/mounts/${ name }" ]
                                                                                                                                                else if type == "temporary-file" then [ "--bind" ''${ "$" }TEMPORARY_${ builtins.hashString "sha512" name }'' "/mounts/${ name }" ]
                                                                                                                                                else builtins.throw "unsupported type ${ type }" ;
                                                                                                                                        in builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs mapper mounts ) )
                                                                                                                                )
                                                                                                                                [
                                                                                                                                    "--bind" "$OUTPUT_FILE" "/output"
                                                                                                                                    "--tmpfs" "/private"
                                                                                                                                    "--tmpfs" "/temporary"
                                                                                                                                ]
                                                                                                                            ] ;
                                                                                                                    name = "user-environment" ;
                                                                                                                    runScript = "script" ;
                                                                                                                    targetPkgs =
                                                                                                                        pkgs :
                                                                                                                            [
                                                                                                                                (
                                                                                                                                    pkgs.writeShellApplication
                                                                                                                                        {
                                                                                                                                            name = "application" ;
                                                                                                                                            runtimeInputs = runtime-inputs pkgs ;
                                                                                                                                            text = text ;
                                                                                                                                        }
                                                                                                                                )
                                                                                                                                (
                                                                                                                                    pkgs.writeShellApplication
                                                                                                                                        {
                                                                                                                                            name = "script" ;
                                                                                                                                            runtimeInputs =
                                                                                                                                                [
                                                                                                                                                    ( _config.failure { } )
                                                                                                                                                    pkgs.coreutils
                                                                                                                                                    pkgs.jq
                                                                                                                                                ] ;
                                                                                                                                            text =
                                                                                                                                                ''
                                                                                                                                                    mapfile -t ARGUMENTS < <(
                                                                                                                                                        jq --raw-output '.arguments[]' /input
                                                                                                                                                    )
                                                                                                                                                    if jq --exit-status 'has("inputs") and (.inputs | has("standard"))' /input > /private/exit-status
                                                                                                                                                    then
                                                                                                                                                        STANDARD_INPUT="$( jq --raw-output '.inputs.standard' /input )" || failure 7828132754944749
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
                                                                                                                                                        }' > /output
                                                                                                                                                '' ;
                                                                                                                                        }
                                                                                                                                )
                                                                                                                            ] ;
                                                                                                                }
                                                                                                        )
                                                                                                    ] ;
                                                                                                text =
                                                                                                    ''
                                                                                                        INPUT_FILE="$( mktemp --suffix ".json" )" || failure 3433420567599724
                                                                                                        export INPUT_FILE
                                                                                                        OUTPUT_FILE="$( mktemp --suffix ".json" )" || failure 4306417545755399
                                                                                                        export OUTPUT_FILE
                                                                                                        ${ builtins.concatStringsSep "/" ( builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs ( name : { source ? null , type } : if type == "temporary-directory" then [ ''TEMPORARY_${ builtins.hashString "sha512" name }=$( mktemp --directory )" || failure 2348666420719031 ${ name }'' ] else [ ] ) mounts ) ) ) }
                                                                                                        ${ builtins.concatStringsSep "/" ( builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs ( name : { source ? null , type } : if type == "temporary-file" then [ ''TEMPORARY_${ builtins.hashString "sha512" name }=$( mktemp )" || failure 2348666420719031 ${ name }'' ] else [ ] ) mounts ) ) ) }
                                                                                                        trap cleanup EXITextraBwrap
                                                                                                        if [[ -t 0 ]]
                                                                                                        then
                                                                                                            jq \
                                                                                                                --null-input \
                                                                                                                --args \
                                                                                                                '{
                                                                                                                    "arguments" : $ARGS.positional
                                                                                                                }' -- "$@" > "$INPUT_FILE"
                                                                                                        else
                                                                                                            STANDARD_INPUT="$( cat )" || failure 6712938899436674
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
                                                                                                                }' -- "$@" > "$INPUT_FILE"
                                                                                                        fi
                                                                                                        user-environment
                                                                                                        STANDARD_ERROR="$( jq --raw-output '.["standard-error"]' "$OUTPUT_FILE" )" || failure 8856851932761746
                                                                                                        echo -n "$STANDARD_ERROR" >&2
                                                                                                        STANDARD_OUTPUT="$( jq --raw-output '.["standard-output"]' "$OUTPUT_FILE" )" || failure 9396616715561937
                                                                                                        echo -n "$STANDARD_OUTPUT"
                                                                                                        STATUS="$( jq --raw-output '.["status"]' "$OUTPUT_FILE" )" || failure 9357282994784138
                                                                                                        exit "$STATUS"
                                                                                                    '' ;
                                                                                            } ;
                                                                        type = _lib.types.functionTo _lib.types.package ;
                                                                    } ;
                                                        } ;
                                            } ;
                            in
                                {
                                    check =
                                        {
                                            failure ,
                                            nixosTest ,
                                            obviated-by ,
                                            test-setup ,
                                            visitor
                                        } :
                                        {
                                            mounts ,
                                            name ,
                                            post ,
                                            runtime-inputs ,
                                            text
                                        } :
                                        {
                                            arguments ? [ ] ,
                                            standard-error ? "" ,
                                            standard-input ? null ,
                                            standard-output ? "" ,
                                            status ? 0
                                        } :
                                            let
                                                test =
                                                    nixosTest
                                                        {
                                                            name = "nixos-test" ;
                                                            nodes.client =
                                                                { config , pkgs , ... } :
                                                                    let
                                                                        _config = config-identity config ;
                                                                        _pkgs = pkgs-identity pkgs ;
                                                                        in
                                                                            {
                                                                                config =
                                                                                    {
                                                                                        environment.systemPackages =
                                                                                            [
                                                                                                (
                                                                                                    _pkgs.writeShellApplication
                                                                                                        {
                                                                                                            name = "test-setup" ;
                                                                                                            runtimeInputs = [ _pkgs.coreutils ] ;
                                                                                                            text = test-setup ;
                                                                                                        }
                                                                                                )
                                                                                                (
                                                                                                    _pkgs.writeShellApplication
                                                                                                        {
                                                                                                            name = "test-script" ;
                                                                                                            runtimeInputs =
                                                                                                                [
                                                                                                                    _pkgs.coreutils
                                                                                                                    _pkgs.diffutils
                                                                                                                    _pkgs.which
                                                                                                                    ( _config.lazy-shell-application { mounts = mounts ; name = name ; post = post ; runtime-inputs = runtime-inputs ; text = text ; } )
                                                                                                                ] ;
                                                                                                            text =
                                                                                                                ''
                                                                                                                    mkdir --parents /build/expected
                                                                                                                    ln --symbolic ${ builtins.toFile "standard-output" standard-output } /build/expected/standard-output
                                                                                                                    ln --symbolic ${ builtins.toFile "standard-error" standard-error } /build/expected/standard-error
                                                                                                                    echo ${ builtins.toString status } > /build/expected/status
                                                                                                                    mkdir --parents /build/observed
                                                                                                                    exec 0<&-
                                                                                                                    # shellcheck disable=SC2065
                                                                                                                    if ${ name } ${ builtins.concatStringsSep " " arguments } ${ if builtins.typeOf standard-input == "null" then "" else "< ${ builtins.toFile "standard-input" standard-input }" } > /build/observed/standard-output 2> /build/observed/standard-error
                                                                                                                    then
                                                                                                                        # shellcheck disable=SC2319
                                                                                                                        STATUS="$?"
                                                                                                                    else
                                                                                                                        # shellcheck disable=SC2319
                                                                                                                        STATUS="$?"
                                                                                                                    fi
                                                                                                                    echo "$STATUS" > /build/observed/status
                                                                                                                    diff --recursive --unified /build/expected /build/observed
                                                                                                                '' ;
                                                                                                        }
                                                                                                )
                                                                                            ] ;
                                                                                    } ;
                                                                                imports = [ failure implementation ] ;
                                                                            } ;
                                                            testScript =
                                                                ''
                                                                    client.wait_for_unit("multi-user.target")
                                                                    client.succeed("test-setup")
                                                                    client.succeed("test-script")
                                                                '' ;
                                                        } ;
                                                in
                                                    {
                                                        obviated-by = obviated-by ;
                                                        test = test ;
                                                        type = "lazy-shell-application" ;
                                                    } ;
                                    implementation = implementation ;
                                } ;
            } ;
}