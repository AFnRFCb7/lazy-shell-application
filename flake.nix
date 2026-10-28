{
    inputs = { } ;
    outputs =
        { self } :
            {
                lib =
                    {
                        _class ? x : x ,
                        _file ? x : x ,
                        config ? x : x ,
                        disableModules ? x : x ,
                        freeFormType ? x : x ,
                        implementation ? x : x ,
                        imports ? x : x ,
                        key ? x : x ,
                        lib ? x : x ,
                        meta ? x : x ,
                        modulesPath ? x : x ,
                        options ? x : x ,
                        pkgs ? x : x ,
                        specialArgs ? x : x
                    } @identity :
                        let
                            implementation =
                                { _class , _file , config , disableModules , freeFormType , imports , key , lib , meta , modulesPath , options , pkgs , specialArgs } @module:
                                    let
                                        identified = lib.mapAttrs ( name : value : builtins.getAttr name identity ( builtins.attr name module ) ) ( module.lib.intersectLists ( builtins.attrNames identity ) ( builtins.attrNames module ) ) ;
                                        in
                                            {
                                                options =
                                                    identified.options
                                                        {
                                                            lazy-shell-application =
                                                                identified.lib.mkOption
                                                                    {
                                                                        default =
                                                                            {
                                                                                mounts ,
                                                                                name ,
                                                                                post ,
                                                                                runtime-inputs ,
                                                                                text ,
                                                                                variables
                                                                            } :
                                                                                let
                                                                                    parameters =
                                                                                        {
                                                                                            mounts = mounts ;
                                                                                            name =
                                                                                                if name == "test" then identified.config.trip "test is not a good name"
                                                                                                else name ;
                                                                                            post = post ;
                                                                                            runtime-inputs = runtime-inputs ;
                                                                                            text = text ;
                                                                                            variables = variables ;
                                                                                        } ;
                                                                                    in
                                                                                        identified.pkgs.writeShellApplication
                                                                                            {
                                                                                                name = parameters.name ;
                                                                                                runtimeInputs =
                                                                                                    [
                                                                                                        ( identified.config.failure { } )
                                                                                                        identified.pkgs.coreutils
                                                                                                        identified.pkgs.jq
                                                                                                        (
                                                                                                            identified.pkgs.writeShellApplication
                                                                                                                {
                                                                                                                    name = "cleanup" ;
                                                                                                                    runtimeInputs = [ identified.pkgs.coreutils ] ;
                                                                                                                    text =
                                                                                                                        identified.config.visitor
                                                                                                                            { }
                                                                                                                            {
                                                                                                                                null =
                                                                                                                                    path : value :
                                                                                                                                        ''
                                                                                                                                            rm --force "$INPUT_FILE" "$OUTPUT_FILE"
                                                                                                                                            ${ builtins.concatStringsSep "\n" ( builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs ( name : { source ? null , type , ... } : if type == "temporary" then [ ''# shellcheck disable=SC2154'' ''rm --recursive --force "$TEMPORARY_${ builtins.hashString "sha512" name }"'' ] else [ ] ) mounts ) ) ) }
                                                                                                                                        '' ;
                                                                                                                                string =
                                                                                                                                    path : value :
                                                                                                                                        ''
                                                                                                                                            nohup nice --adjustment 19 "${ value }" > /dev/null 2>&1
                                                                                                                                            rm --force "$INPUT_FILE" "$OUTPUT_FILE"
                                                                                                                                            ${ builtins.concatStringsSep "\n" ( builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs ( name : { source ? null , type , ... } : if type == "pipe" then [ ''# shellcheck disable=SC2154'' ''rm --recursive --force "$TEMPORARY_${ builtins.hashString "sha512" name }"'' ] else [ ] ) mounts ) ) ) }
                                                                                                                                            ${ builtins.concatStringsSep "\n" ( builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs ( name : { delete ? true , source ? null , type , ... } : if type == "temporary" && delete then [ ''# shellcheck disable=SC2154'' ''rm --recursive --force "$TEMPORARY_${ builtins.hashString "sha512" name }"'' ] else [ ] ) mounts ) ) ) }
                                                                                                                                       '' ;
                                                                                                                            }
                                                                                                                            post ;
                                                                                                                }
                                                                                                        )
                                                                                                        (
                                                                                                            identified.pkgs.writeShellApplication
                                                                                                                {
                                                                                                                    name = "pipe-consumer" ;
                                                                                                                    runtimeInputs = [ identified.pkgs.coreutils ] ;
                                                                                                                    text =
                                                                                                                        ''
                                                                                                                            TEMPORARY_PIPE="$1"
                                                                                                                            CHANNEL="$2"
                                                                                                                            mkfifo "$TEMPORARY_PIPE"
                                                                                                                            nohup cat "$TEMPORARY_PIPE" >&"$CHANNEL" > /dev/null >&2 &
                                                                                                                        '' ;
                                                                                                                }
                                                                                                        )
                                                                                                        (
                                                                                                            identified.pkgs.buildFHSUserEnv
                                                                                                                {
                                                                                                                    extraBwrapArgs =
                                                                                                                        builtins.concatLists
                                                                                                                            [
                                                                                                                                [
                                                                                                                                    "--ro-bind" "$INPUT_FILE" "/input"
                                                                                                                                    "--bind" "$OUTPUT_FILE" "/output"
                                                                                                                                    "--tmpfs" "/private"
                                                                                                                                ]
                                                                                                                                (
                                                                                                                                    let
                                                                                                                                        mapper =
                                                                                                                                            name : { delete ? true , is-directory ? true , read-only ? false , source ? null , type } :
                                                                                                                                                if type == "bind" && read-only then [ "--ro-bind" source "/mounts/${ name }" ]
                                                                                                                                                else if type == "bind" && ! read-only then [ "--bind" source "/mounts/${ name }" ]
                                                                                                                                                else if type == "temporary" && read-only then [ "--bind" ''${ "$" }TEMPORARY_${ builtins.hashString "sha512" name }'' "/mounts/${ name }" ]
                                                                                                                                                else if type == "temporary" && ! read-only then [ "--bind" ''${ "$" }TEMPORARY_${ builtins.hashString "sha512" name }'' "/mounts/${ name }" ]
                                                                                                                                                else if type == "memory" && read-only && is-directory then [ "--tmpfs" "/mounts/${ name }" "--remount-ro" "/mounts/${ name }" ]
                                                                                                                                                else if type == "memory" && read-only && ! is-directory then identified.config.trip "memory and read-only and ! directory makes no sense "
                                                                                                                                                else if type == "memory" && ! read-only && is-directory then [ "--tmpfs" "/mounts/${ name }" ]
                                                                                                                                                else if type == "memory" && ! read-only && ! is-directory then [ "--tmpfs" "/memory/${ name }" ]
                                                                                                                                                else if type == "null" && read-only then identified.config.trip "read-only null make no sense"
                                                                                                                                                else if type == "null" && is-directory then identified.config.trip "directory null make no sense"
                                                                                                                                                else if type == "null" then [ "--bind" ''${ "$" }TEMPORARY_${ builtins.hashString "sha512" name }'' "/dev/null" ]
                                                                                                                                                else if type == "pipe" && read-only then identified.config.trip "read-only pipes make no sense"
                                                                                                                                                else if type == "pipe" && is-directory then identified.config.trip "directory pipes make no sense"
                                                                                                                                                else if type == "pipe" then [ ''--bind ''$TEMPORARY_${ builtins.hashString "sha512" name }'' "/mount/${ name }" ]
                                                                                                                                                else identified.config.trip "unsupported type ${ type }" ;
                                                                                                                                        in builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs mapper mounts ) )
                                                                                                                                )
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
                                                                                                                                                    ( identified.config.failure { } )
                                                                                                                                                    pkgs.coreutils
                                                                                                                                                    pkgs.findutils
                                                                                                                                                    pkgs.jq
                                                                                                                                                ] ;
                                                                                                                                            text =
                                                                                                                                                ''
                                                                                                                                                    if [[ -d /memory ]]
                                                                                                                                                    then
                                                                                                                                                        find /memory -mindepth 1 -maxdepth 1 -type d | while read -r DIRECTORY
                                                                                                                                                        do
                                                                                                                                                            BASENAME="$( basename "$DIRECTORY" )" || failure 9613707705785031
                                                                                                                                                            ln --symbolic "$DIRECTORY/$BASENAME" "/mounts/$BASENAME"
                                                                                                                                                        done
                                                                                                                                                    fi
                                                                                                                                                    mapfile -t ARGUMENTS < <(
                                                                                                                                                        jq --raw-output '.arguments[]' /input
                                                                                                                                                    )
                                                                                                                                                    ${ builtins.concatStringsSep "\n" ( builtins.attrValues ( builtins.mapAttrs ( name : value : ''${ name }="$( jq --raw-output '.variables.${ name }' /input ) || failure 9367334832748350'' ) variables ) ) }
                                                                                                                                                    ${ builtins.concatStringsSep "\n" ( builtins.attrValues ( builtins.mapAttrs ( name : value : ''export ${ name }'' ) variables ) ) }
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
                                                                                                                                                            "outputs" :
                                                                                                                                                                {
                                                                                                                                                                    "standard-error" : $STANDARD_ERROR ,
                                                                                                                                                                    "standard-output" : $STANDARD_OUTPUT
                                                                                                                                                                } ,
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
                                                                                                        ${ builtins.concatStringsSep "\n" ( builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs ( name : { is-directory ? true , source ? null , type , ... } : if type == "bind" && is-directory == true then [ ''mkdir --parents "${ source }"'' ] else [ ] ) mounts ) ) ) }
                                                                                                        ${ builtins.concatStringsSep "\n" ( builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs ( name : { is-directory ? true , source ? null , type , ... } : if type == "bind" && is-directory == false then [ ''DIRECTORY="$( dirname ${ source } )" || failure 4036755818456657'' ''if [[ ! -d "$DIRECTORY" ]] ; then mkdir --parents "$DIRECTORY" ; fi'' ''touch ${ source }'' ] else [ ] ) mounts ) ) ) }
                                                                                                        ${ builtins.concatStringsSep "\n" ( builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs ( name : { is-directory ? true , source ? null , type , ... } : if type == "pipe" then [ ''TEMPORARY_${ builtins.hashString "sha512" name }="$( mktemp --dry-run )" || failure 8929529915872102 ${ type } ${ name }'' ''export TEMPORARY_${ builtins.hashString "sha512" name }'' ] else [ ] ) mounts ) ) ) }
                                                                                                        ${ builtins.concatStringsSep "\n" ( builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs ( name : { is-directory ? true , source ? null , type , ... } : if type == "temporary" then [ ''TEMPORARY_${ builtins.hashString "sha512" name }="$( mktemp ${ if is-directory then "--directory" else "" } )" || failure 2348666420719031 ${ type } ${ name }'' ''export TEMPORARY_${ builtins.hashString "sha512" name }'' ] else [ ] ) mounts ) ) ) }
                                                                                                        ${ builtins.concatStringsSep "\n" ( builtins.concatLists ( builtins.attrValues ( builtins.mapAttrs ( name : { source ? null , type , ... } : if type == "pipe" then [ ''pipe-consumer "${ "$" }TEMPORARY_${ builtins.hashString "sha512" name }" ${ builtins.toString source }'' ] else [ ] ) mounts ) ) ) }
                                                                                                        trap cleanup EXIT
                                                                                                        if [[ ! -e /dev/fd/0 ]] || [[ -t 0 ]]
                                                                                                        then
                                                                                                            jq \
                                                                                                                --null-input \
                                                                                                                ${ builtins.concatStringsSep "" ( builtins.attrValues ( builtins.mapAttrs ( name : value : ''--arg VAR_${ builtins.hashString "sha512" name } "${ value }'' ) parameters.variables ) ) } \
                                                                                                                --args \
                                                                                                                '{
                                                                                                                    "arguments" : $ARGS.positional ,
                                                                                                                    "inputs" : { } ,
                                                                                                                    "variables" : { ${ builtins.concatStringsSep " " ( builtins.attrValues ( builtins.mapAttrs ( name : value : ''${ builtins.hashString "sha512" name } : ${ "$" }VAR_${ name } ,'' ) parameters.variables ) ) } }
                                                                                                                }' -- "$@" > "$INPUT_FILE"
                                                                                                        else
                                                                                                            STANDARD_INPUT="$( cat )" || failure 6712938899436674
                                                                                                            jq \
                                                                                                                --null-input \
                                                                                                                --arg STANDARD_INPUT "$STANDARD_INPUT" \
                                                                                                                ${ builtins.concatStringsSep "" ( builtins.attrValues ( builtins.mapAttrs ( name : value : ''--arg VAR_${ builtins.hashString "sha512" name } "${ value }'' ) parameters.variables ) ) } \
                                                                                                                --args \
                                                                                                                '{
                                                                                                                    "arguments" : $ARGS.positional ,
                                                                                                                    "inputs" :
                                                                                                                        {
                                                                                                                            "standard" : $STANDARD_INPUT
                                                                                                                        } ,
                                                                                                                    "variables" : { ${ builtins.concatStringsSep " " ( builtins.attrValues ( builtins.mapAttrs ( name : value : ''${ name } : ${ "$" }VAR_${ builtins.hashString "sha512" name } ,'' ) parameters.variables ) ) } }
                                                                                                                }' -- "$@" > "$INPUT_FILE"
                                                                                                        fi
                                                                                                        user-environment
                                                                                                        STANDARD_ERROR="$( jq --raw-output '.outputs.["standard-error"]' "$OUTPUT_FILE" )" || failure 8856851932761746
                                                                                                        echo -n "$STANDARD_ERROR" >&2
                                                                                                        STANDARD_OUTPUT="$( jq --raw-output '.outputs.["standard-output"]' "$OUTPUT_FILE" )" || failure 9396616715561937
                                                                                                        echo -n "$STANDARD_OUTPUT"
                                                                                                        STATUS="$( jq --raw-output '.["status"]' "$OUTPUT_FILE" )" || failure 9357282994784138
                                                                                                        exit "$STATUS"
                                                                                                    '' ;
                                                                                            } ;
                                                                        type = identified.lib.types.functionTo identified.lib.types.package ;
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
                                            post-test ,
                                            pre-test ,
                                            trip ,
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
                                                                { config , pkgs , ... } @module :
                                                                    let
                                                                        identified = lib.mapAttrs ( name : value : builtins.getAttr name identity ( builtins.attr name module ) ) ( module.lib.intersectLists ( builtins.attrNames identity ) ( builtins.attrNames module ) ) ;
                                                                        in
                                                                            {
                                                                                config =
                                                                                    {
                                                                                        environment.systemPackages =
                                                                                            [
                                                                                                (
                                                                                                    identified.pkgs.writeShellApplication
                                                                                                        {
                                                                                                            name = "post-test" ;
                                                                                                            runtimeInputs = [ identified.pkgs.coreutils identified.pkgs.flock ] ;
                                                                                                            text =
                                                                                                                ''
                                                                                                                    exec 123>/build/lock
                                                                                                                    flock -x 123
                                                                                                                    ${ if builtins.typeOf post-test == "null" then "" else post-test }
                                                                                                                '' ;
                                                                                                        }
                                                                                                )
                                                                                                (
                                                                                                    identified.pkgs.writeShellApplication
                                                                                                        {
                                                                                                            name = "pre-test" ;
                                                                                                            runtimeInputs = [ identified.pkgs.coreutils ] ;
                                                                                                            text = pre-test ;
                                                                                                        }
                                                                                                )
                                                                                                (
                                                                                                    identified.pkgs.writeShellApplication
                                                                                                        {
                                                                                                            name = "test-script" ;
                                                                                                            runtimeInputs =
                                                                                                                [
                                                                                                                    identified.pkgs.coreutils
                                                                                                                    identified.pkgs.diffutils
                                                                                                                    identified.pkgs.flock
                                                                                                                    identified.pkgs.which
                                                                                                                    (
                                                                                                                        identified.config.lazy-shell-application
                                                                                                                            {
                                                                                                                                mounts = mounts ;
                                                                                                                                name = name ;
                                                                                                                                post =
                                                                                                                                    let
                                                                                                                                        application =
                                                                                                                                            identified.pkgs.writeShellApplication
                                                                                                                                                {
                                                                                                                                                    name = "post" ;
                                                                                                                                                    runtimeInputs = [ ( identified.config.failure { } ) pkgs.coreutils pkgs.flock ] ;
                                                                                                                                                    text =
                                                                                                                                                        ''
                                                                                                                                                            exec 123>/build/lock
                                                                                                                                                            flock -x 123
                                                                                                                                                            ${ if builtins.typeOf post == "null" then "" else post }
                                                                                                                                                        '' ;
                                                                                                                                                } ;
                                                                                                                                        in "${ application }/bin/post" ;
                                                                                                                                runtime-inputs = runtime-inputs ;
                                                                                                                                text = text ;
                                                                                                                                variables = { } ;
                                                                                                                            }
                                                                                                                    )
                                                                                                                ] ;
                                                                                                            text =
                                                                                                                ''
                                                                                                                    mkdir --parents /build/expected
                                                                                                                    ln --symbolic ${ builtins.toFile "standard-output" standard-output } /build/expected/standard-output
                                                                                                                    ln --symbolic ${ builtins.toFile "standard-error" standard-error } /build/expected/standard-error
                                                                                                                    echo ${ builtins.toString status } > /build/expected/status
                                                                                                                    mkdir --parents /build/observed
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
                                                                                imports = [ failure implementation trip visitor ] ;
                                                                            } ;
                                                            testScript =
                                                                ''
                                                                    client.wait_for_unit("multi-user.target")
                                                                    client.succeed("pre-test")
                                                                    client.succeed("test-script")
                                                                    client.succeed("post-test")
                                                                '' ;
                                                        } ;
                                                in
                                                    {
                                                        obviated-by = obviated-by ;
                                                        test = test ;
                                                        type = "lazy-shell-application" ;
                                                    } ;
                                    implementation = identity.implementation implementation ;
                                } ;
            } ;
}