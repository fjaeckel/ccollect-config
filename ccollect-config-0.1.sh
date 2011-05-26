#!/bin/sh
#
#   Filename:       ccollect-config-0.1.sh
#   Author:         Frederic 'jchome' Jaeckel
#   Email:          jaeckelf 'at' refuzed 'dot' org
#   Homepage:       http://0xf00.de
#   Description:    This is a small, portable frontend for a
#                   easier configuration of the ccollect backup
#                   solution.

# just a boring tmp file saved in the var `tmp`
tmp=$(mktemp /tmp/$(basename $0).XXXXXXXX);

# the title for all dialogs
TITLE="ccollect-config";

# check for the existance of dialog
check_dialog() {
    IFS=':';
    for i in ${PATH};
    do
        if [ -x "${i}/$1" ];
        then
            echo "${i}/$1";
            return 0;
        fi;
    done;
    return 1;
}
DIALOG="$(check_dialog dialog)";
if [ $? -ne 0 ];
then
    echo "error: dialog not found, please install it.";
    exit 1;
fi;

# we have to check for the $EDITOR env variable, cause we really need it.
check_editor() {
    which "${EDITOR}" 1>/dev/null;
    if [ $? -ne 0 ];
    then
        which "${VISUAL}" 1>/dev/null;
        if [ $? -ne 0 ];
        then
            echo "EDITOR is not set. To proceed, please set the \$EDITOR variable. \`export EDITOR=\"/usr/bin/vim\"\`";
            return 1;
        fi;
    fi;
    return 0;
}
# calling the function `check_editor` and check it's return value
check_editor;
if [ $? -ne 0 ];
then
    exit 1;
fi;


DIALOG="$(check_dialog dialog) --title ${TITLE}";

# we need a special routine wether ${CCOLLECT_CONF} is set or not.
if [ -z "${CCOLLECT_CONF}" ];
then 
    CCOLLECT_CONF="/etc/ccollect";
fi;

# a inputbox for typing the default configuration directory
cfgpath() {
    ${DIALOG} --inputbox "Please enter the path for the config." 15 55 "${CCOLLECT_CONF}" 2>"${tmp}";
    [ $? -ne 0 ] && return
    CFG_PATH=$(cat "${tmp}");
    create_cfg_env;
}

# if this is a new install we have to create the directories
# and the necessary files.
create_cfg_env() {
    mkdir -p "${CFG_PATH}/defaults/intervals";
    mkdir "${CFG_PATH}/sources";
    main_menu;
    if [ $? -ne 0 ];
    then
        echo "error in function main_menu. please send a bugreport.";
        exit 1;
    fi;
}

# the main menu, where you can configure everything
main_menu() {
    ${DIALOG} --menu "Move using [UP] [DOWN],[Enter] to select." 15 60 4 \
    'interval'  "edit intervals"\
    'exec'      "configure pre and post executions"\
    'sources'   "configure your backup sources"\
    'exit'      "finished." 2> "${tmp}";

    selection=$(cat "${tmp}");
    
    case "${selection}" in \
        "interval") interval ;;
        "exec")     execs ;;
        "sources")  src_menu ;;
        "exit")     return 0 ;;
    esac
}

# a standard interval menu to choose a action
interval() {
    ${DIALOG} --menu "Move using [UP] [DOWN],[Enter] to select." 15 60 5 \
    'add'   "add an interval."\
    'del'   "delete an interval."\
    'edit'  "edit an interval."\
    'list'  "list all intervals."\
    'ready' "I'm ready with configuring intervals. Go ahead." 2> "${tmp}";

    selection=$(cat "${tmp}");

    case "${selection}" in \
        "add")  interval_add ;;
        "del")  interval_del ;;
        "edit") interval_edit;
                if [ $? -ne 0 ];
                then
                    echo "error in function interval_edit. please send a bugreport.";
                    exit 1;
                fi;;
        "list") interval_list ;;
        "ready") main_menu ;;
    esac
}

# the subroutine for adding intervals to the default settings
# can also be used for the sources
interval_add() {
    ${DIALOG} --inputbox "Enter the name of the interval you want to add." 15 55 "weekly" 2>"${tmp}";
    intv=$(cat "${tmp}");

    ${DIALOG} --inputbox "Please enter the amount of kept backs for this interval." 15 55 "23" 2>"${tmp}";
    amount=$(cat "${tmp}");
    echo "${amount}" > "${CFG_PATH}/defaults/intervals/${intv}";
    interval;
}

# the subroutine for the deletion of default intervals
interval_del() {
    amount=0;
    for i in $(ls "${CFG_PATH}/defaults/intervals/");
    do
        amount=$(echo "${amount} + 1"|bc);
    done;
    list=$(ls "${CFG_PATH}/defaults/intervals/");

    # just some error callbacks for the case
    # if there is no interval
    if [ "${amount}" != 0 ];
    then
        ${DIALOG} --radiolist "Please select the interval to delete." 15 55 ${amount} \
        $(for i in ${list};
        do
            echo -n "$i ";
            echo -n "$i ";
            echo "off";
        done;) 2>"${tmp}";
        intv=$(cat "${tmp}");

        if [ "${intv}" != 0 ];
        then
            rm "${CFG_PATH}/defaults/intervals/${intv}"; 
        fi;
    else
        ${DIALOG} --msgbox "You have no default intervals, so you cant delete any." 15 55;
    fi;
    interval;
}

# the subroutine for editing known intervals
interval_edit() {
    amount=0;
    for i in $(ls "${CFG_PATH}/defaults/intervals/");
    do
        amount=$(echo "${amount} + 1"|bc);
    done;
    list=$(ls "${CFG_PATH}/defaults/intervals/");
    ${DIALOG} --radiolist "Please select the interval to edit." 15 55 ${amount} \
    $(for i in ${list};
    do
        echo -n "$i ";
        echo -n "$i ";
        echo "off";
    done;) 2>"${tmp}";
    intv=$(cat "${tmp}");

    old_kepts=$(cat "${CFG_PATH}/defaults/intervals/${intv}"); 
    ${DIALOG} --inputbox "Please enter the new value for ${intv}." 15 55 ${old_kepts} 2>"${tmp}";
    kepts=$(cat "${tmp}");

    if [ "${kepts}" -ne 0 ];
    then
        if [ -n "${kepts}" ];
        then
            echo "${kepts}" > "${CFG_PATH}/defaults/intervals/${intv}";
        else
            echo "error: kepts is empty.";
            return 1;
        fi;
    else
        echo "error: number of kepts doesnt exist.";
        return 1;
    fi;
    interval;
}

# lists all available intervals
interval_list() {
    rm "${tmp}";
    for i in $(ls "${CFG_PATH}/defaults/intervals/"); 
    do 
        echo "$i   $(cat "${CFG_PATH}/defaults/intervals/$i")" >> "${tmp}"; 
    done;
    ${DIALOG} --msgbox "$(cat "${tmp}")" 15 55;
    interval;
}

execs() {
    ${DIALOG} --yesno "Do you want any kind of pre or post execution by default?" 15 55;
    selection="$?";
    
    case "${selection}" in \
        0)  pre_exec;;
        1)  main_menu;;
        255) echo "Canceled by user by pressing [ESC] key";;
    esac

}

pre_exec() {
    ${DIALOG} --yesno "Do you want a prexecution? This can be a shellscript, a program, anything wich is executeable on *NIX shells." 15 55;
    selection="$?";
    case "${selection}" in \
        0)  pre_exec_input;;
        1)  post_exec;;
        255) echo "Canceled by user by pressing [ESC] key";;
    esac
}

exec_input() {
    ${DIALOG} --inputbox "Please type here your shell compliant execution code:" 15 55 2>"${tmp}";
    selection=$(cat "${tmp}");
}

pre_exec_input() {
    exec_input;
    echo "${selection}" > "${CFG_PATH}/defaults/pre_exec";
    post_exec;
}

post_exec() {
    ${DIALOG} --yesno "Do you want a postexecution? This can be a shellscript, a program, anything wich is executeable on *NIX shells." 15 55;
    selection="$?";
    case "${selection}" in \
        0)  post_exec_input;;
        1)  main_menu;;
        255) echo "Canceled by user by pressing [ESC] key";;
    esac
}

post_exec_input() {
    exec_input;
    echo "${selection}" > "${CFG_PATH}/defaults/post_exec";
    main_menu;
}

# the main menu where all source actions can be called.
src_menu() {
    ${DIALOG} --menu "You are now able to add/edit/delete/view your backup sources." 15 55 5\
    'add'   "add a new backup source" \
    'del'   "delete a existing backup source" \
    'edit'  "edit a existing backup source" \
    'list'  "list all backup sources" \
    'ready' "ready with configuration." 2>"${tmp}";
    selection=$(cat "${tmp}");

    case "${selection}" in \
        'add')  src_add;;
        'del')  src_del;;
        'edit') src_edit;;
        'list') src_list;;
        'ready') main_menu;;
    esac;
}

# with this function you can add sources to the configuration.
src_add() {
    # a symbolic name for the source is needed.
    ${DIALOG} --inputbox "Please enter a name for the new source (eg. the name of the computer)." 15 55 2>"${tmp}";
    NAME=$(cat "${tmp}");
    if [ -w "${CFG_PATH}/sources/${NAME}" ];
    then
        rm -r "${CFG_PATH}/sources/${NAME}";
    fi;
    mkdir -p "${CFG_PATH}/sources/${NAME}";

    # here are the src_add_* functions executed.
    # mostly all functions return a code for the errorchecks.
    src_add_destination;
    src_add_src;
    if [ $? -ne 0 ];
    then
        echo "error in function src_add_source. please submit a bugreport.";
        exit 1;
    fi;
    src_add_verbosity;
    if [ $? -ne 0 ];
    then
        echo "error in function src_add_verbosity. please submit a bugreport.";
        exit 1;
    fi;
    src_add_summary;
    if [ $? -ne 0 ];
    then
        echo "error in function src_add_summary. please submit a bugreport.";
        exit 1;
    fi;
    src_add_rsync;
    if [ $? -ne 0 ];
    then
        echo "error in function src_add_rsync. please submit a bugreport.";
        exit 1;
    fi;
    src_add_exclude;
    if [ "$?" -ne 0 ];
    then
        echo "error in function src_add_exclude. please submit a bugreport.";
        exit 1;
    fi;
    src_add_preexec;
}

# the destination folder has to be specified.
src_add_destination() {
    ${DIALOG} --inputbox "Enter path to backup TO. eg: /home/backup/testsource " 15 55 2>"${tmp}";
    BACKUP_DIR=$(cat "${tmp}");
    mkdir -p "${BACKUP_DIR}";
    ln -sf "${BACKUP_DIR}" "${CFG_PATH}/sources/${NAME}/destination";
}

# we also need the access to the source of the backup via rsync
src_add_src() {
    ${DIALOG} --inputbox "Please enter the source address. For rsync over ssh eg.: USER@HOST:/path/to/dir/to/backup \nFor rsync without ssh enter something like that: rsync::USER@HOST/SRC\nThis can also be a local path: /home/backup/foo.bar.lan" 15 55 2>"${tmp}";
    SOURCE=$(cat "${tmp}");
    if [ -f "${CFG_PATH}/sources/${NAME}/source" ];
    then
        rm "${CFG_PATH}/sources/${NAME}/source";
        echo "${SOURCE}" > "${CFG_PATH}/sources/${NAME}/source";
        return 0;
    else
        echo "${SOURCE}" > "${CFG_PATH}/sources/${NAME}/source";
        return 0;
    fi;
    return 1;
}

# specify the verbosity
src_add_verbosity() {
    ${DIALOG} --menu "Do you want any kind of verbosity?" 15 55 3\
    'quiet' "no verbosity" \
    'verbose'   "be verbose but dont print all infos" \
    'very_verbose'  "print all infos" 2>"${tmp}";
    selection=$(cat "${tmp}");

    case "${selection}" in \
        'quiet')        return 0;;
        'verbose')      if [ -f "${CFG_PATH}/sources/${NAME}/verbose" ];
                        then 
                            rm -r "${CFG_PATH}/sources/${NAME}/verbose"; 
                        fi; 
                        touch "${CFG_PATH}/sources/${NAME}/verbose"; 
                        return 0;;
        'very_verbose') if [ -f "${CFG_PATH}/sources/${NAME}/very_verbose" ];
                        then 
                            rm -r "${CFG_PATH}/sources/${NAME}/very_verbose"; 
                        fi; 
                        touch "${CFG_PATH}/sources/${NAME}/very_verbose"; 
                        return 0;;
    esac;
    return 1;
}

# specify if a summary for this source is needed or not.
src_add_summary() {
    ${DIALOG} --yesno "Do you want a summary for this source?" 15 55;
    selection="$?";

    case "${selection}" in\
        0)  if [ -f "${CFG_PATH}/sources/${NAME}/summary" ];
            then 
                rm -r "${CFG_PATH}/sources/${NAME}/summary";
            fi; 
            touch "${CFG_PATH}/sources/${NAME}/summary";
            return 0;;
        1)  return 0;;
        255) echo "Canceled by user by pressing [ESC] key";;
    esac
    return 1;
}

# here the user can specify any rsync compliant options.. for further information use
# the rsync manual page.
src_add_rsync() {
    ${DIALOG} --defaultno --yesno "Do you want to specify any additional rsync options for this source?" 15 55;
    selection="$?";

    case "${selection}" in\
        0)      rsync_opts;
                if [ "$?" -ne 0 ];
                then
                    return 1;
                else
                    return 0;
                fi;;
        1)      return 0;;
        255)    echo "Canceled by user by pressing [ESC] key";;
    esac
    return 1;
}

# with this function you can add an excludelist to the source
src_add_exclude() {
    ${DIALOG} --yesno "Do you want to exlude some files/directories of the backup?" 15 55;
    selection="$?";
    
    case "${selection}" in\
        0)      if [ -f "${CFG_PATH}/sources/${NAME}/exclude" ];
                then
                    rm -f "${CFG_PATH}/sources/${NAME}/exclude";
                fi;
                echo "" > "${tmp}";
                ${DIALOG} --msgbox "Now, this script open your default editor where you can add the directories and files separated by newlines." 15 55;
                "${EDITOR}" "${tmp}";
                cat "${tmp}" > "${CFG_PATH}/sources/${NAME}/exclude";
                return 0;
                ;;

        1)      if [ -f "${CFG_PATH}/sources/${NAME}/exclude" ];
                then
                    rm -f "${CFG_PATH}/sources/${NAME}/exclude";
                fi;
                return 0;;
        255)    echo "Canceled by user by pressing [ESC] key";;
    esac
    return 1;
}

src_add_preexec() {
    ${DIALOG} --yesno "Do you want any pre execution for this source?" 15 55;
    selection="$?";

    case "${selection}" in\
        0)      src_pre_exec;;
        1)      src_post;;
        255)    echo "Canceled by user by pressing [ESC] key";;
    esac
}

rsync_opts() {
    ${DIALOG} --inputbox "Put here any rsync options ya want.. but please be rsync conform.. otherwise your backup will fail. \`man rsync\` for details." 15 55 2>"${tmp}";
    selection=$(cat "${tmp}");
    echo "${selection}" > "${CFG_PATH}/sources/${NAME}/rsync_options";
    return 0;
}

src_post() {
    ${DIALOG} --yesno "Do you want any kind of post execution for this source?" 15 55;
    selection="$?";
    case "${selection}" in\
        0)      src_post_exec;;
        1)      src_finmsg;;
        255) echo "Canceled by user by pressing [ESC] key";;
    esac
}

src_pre_exec() {
    exec_input;
    echo "${selection}" > "${CFG_PATH}/sources/${NAME}/pre_exec";
    src_post;
}

src_post_exec() {
    exec_input;
    echo "${selection}" > "${CFG_PATH}/sources/${NAME}/post_exec";
    src_finmsg;
}

# just a boring final message, that the source is added
src_finmsg() {
    ${DIALOG} --msgbox "Your source is successfully added to the base config." 15 55;
    src_menu;
}

# this function deletes a available source unrecoverable
src_del() {
    amount=0;
    for i in $(ls "${CFG_PATH}/sources/");
    do
        amount=$(echo "${amount} + 1"|bc);
    done;

    if [ "${amount}" != 0 ];
    then
        list=$(ls "${CFG_PATH}/sources/");
        height=$(echo "${amount} + 7"|bc);
        ${DIALOG} --radiolist "Please select the source to delete." ${height} 55 ${amount} \
        $(for i in ${list};
        do
            echo -n "$i ";
            echo -n "$i ";
            echo "off";
        done;) 2>"${tmp}";
        src=$(cat "${tmp}");

        if [ -w "${CFG_PATH}/sources/${src}" ];
        then
            rm -rf "${CFG_PATH}/sources/${src}";
        else
            ${DIALOG} --msgbox "The source ${src} isnt writeable." 15 55;
        fi;
    else
        ${DIALOG} --msgbox "You have no sources to delete" 15 55;
    fi;
    src_menu;
}

# this function with its subfunctions is for editing available sources
# on the system.
src_edit() {
    amount=0;
    for i in $(ls "${CFG_PATH}/sources/");
    do
        amount=$(echo "${amount} + 1"|bc);
    done;
    if [ ${amount} -ne 0 ];
    then
        list=$(ls "${CFG_PATH}/sources/");
        height=$(echo "${amount} + 7"|bc);
        ${DIALOG} --radiolist "Please select the source to edit." ${height} 55 ${amount} \
        $(for i in ${list}
        do
            echo -n "${i} ";
            echo -n "${i} ";
            echo "off";
        done;) 2>"${tmp}";
        source=$(cat "${tmp}");
    fi;
    src_edit_destination;
    if [ $? -ne 0 ];
    then
        echo "error in function src_edit_destination. please send a bugreport.";
        exit 1;
    fi;
    src_edit_verbosity;
    if [ $? -ne 0 ];
    then
        echo "error in function src_edit_verbosity. please send a bugreport.";
        exit 1;
    fi;
    src_edit_summary;
    if [ $? -ne 0 ];
    then
        echo "error in function src_edit_summary. please send a bugreport.";
        exit 1;
    fi;
    src_edit_src;
    if [ $? -ne 0 ];
    then
        echo "error in function src_edit_source. please send a bugreport.";
        exit 1;
    fi;
    src_edit_rsync;
    if [ $? -ne 0 ];
    then
        echo "error in function src_edit_rsync. please send a bugreport.";
        exit 1;
    fi;
    src_edit_exclude;
    if [ $? -ne 0 ];
    then
        echo "error in function src_edit_exclude. please submit a bugreport.";
        exit 1;
    fi;
    src_edit_pre;
    if [ $? -ne 0 ];
    then
        echo "error in function src_edit_pre. please send a bugreport.";
        exit 1;
    fi;
    src_edit_post;
    if [ $? -ne 0 ];
    then
        echo "error in function src_edit_post. please send a bugreport.";
        exit 1;
    fi;
    src_edit_finmsg;
}

src_edit_destination() {    
    destination=$(ls -l "${CFG_PATH}/sources/${source}/destination" | awk -F '-> ' '{print $2}');
    ${DIALOG} --inputbox "Your old destination was ${destination}." 15 55 "${destination}" 2>"${tmp}";
    destination=$(cat "${tmp}");
    if [ -f "${CFG_PATH}/sources/${source}/destination" ];
    then
        rm "${CFG_PATH}/sources/${source}/destination";
        ln -sf "${destination} ${CFG_PATH}/sources/${source}/destination";
        return 0;
    else
        ln -sf "${destination} ${CFG_PATH}/sources/${source}/destination";
        return 0;
    fi;
    return 1;
}

src_edit_verbosity() {
    if [ -f "${CFG_PATH}/sources/${source}/verbose" ];
    then
        ${DIALOG} --radiolist "Do you want to be verbose as actually, very_verbose or quiet?" 15 55 3\
        "verbose"   "verbose"   on \
        "very_verbose"  "very_verbose" off\
        "quiet"     "quiet"     off 2>"${tmp}";
        selection=$(cat "${tmp}");

        case "${selection}" in\
            'verbose')      return 0;;
            'very_verbose') rm "${CFG_PATH}/sources/${source}/verbose"; 
                            touch "${CFG_PATH}/sources/${source}/very_verbose";
                            return 0;;
            'quiet')        rm "${CFG_PATH}/sources/${source}/verbose";
                            return 0;;
        esac
    elif [ -f "${CFG_PATH}/sources/${source}/very_verbose" ];
    then
        ${DIALOG} --radiolist "Do you want to be very_verbose as actually, less verbose or quiet?" 15 55 3\
        "verbose"   "verbose"   off\
        "very_verbose"  "very_verbose"  on\
        "quiet"     "quiet"     off 2>"${tmp}";
        selection=$(cat "${tmp}");

        case "${selection}" in\
            'verbose')      rm "${CFG_PATH}/sources/${source}/very_verbose";
                            touch "${CFG_PATH}/sources/${source}/verbose";
                            return 0;;
            'very_verbose') return 0;;
            'quiet')        rm "${CFG_PATH}/sources/${source}/very_verbose";
                            return 0;;
        esac
    else
        ${DIALOG} --radiolist "Do you want to have verbosity?" 15 55 3\
        "verbose"   "verbose"   off\
        "very_verbose"  "very_verbose"  off\
        "quiet"     "quiet"     on 2>"${tmp}";
        selection=$(cat "${tmp}");
        
        case "${selection}" in\
            'verbose')      touch "${CFG_PATH}/sources/${source}/verbose";
                            return 0;;
            'very_verbose') touch "${CFG_PATH}/sources/${source}/very_verbose";
                            return 0;;
            'quiet')        return 0;;
        esac
    fi;
    return 1;
}

src_edit_summary() {    
    ${DIALOG} --yesno "Should be a summary generated after successful backup?" 15 55;
    selection="$?";
    case "${selection}" in\
        0)      if [ ! -f "${CFG_PATH}/sources/${source}/summary" ];
                then
                    touch "${CFG_PATH}/sources/${source}/summary";
                fi;
                return 0;;
        1)      if [ -f "${CFG_PATH}/sources/${source}/summary" ];
                then
                    rm -f "${CFG_PATH}/sources/${source}/summary";
                fi;
                return 0;;
        255)    echo "Canceled by user by pressing [ESC] key";;
    esac
    return 1;
}

src_edit_src() {    
    if [ ! -f "${CFG_PATH}/sources/${source}/source" ];
    then
        ${DIALOG} --inputbox "Please enter the source access. For rsync over ssh eg.: USER@HOST:/path/to/dir/to/backup \nFor rsync without ssh enter something like that: rsync::USER@HOST/SRC" 15 55 2>"${tmp}";
        src=$(cat "${tmp}");
        echo "${src}" > "${CFG_PATH}/sources/${source}/source";
        return 0;
    else
        ${DIALOG} --inputbox "Please enter the source access. For rsync over ssh eg.: USER@HOST:/path/to/dir/to/backup \nFor rsync without ssh enter something like that: rsync::USER@HOST/SRC" 15 55\
            $(cat "${CFG_PATH}/sources/${source}/source") 2>"${tmp}";
        src=$(cat "${tmp}");
        echo "${src}" > "${CFG_PATH}/sources/${source}/source";
        return 0;
    fi;
    return 1;
}

src_edit_rsync() {
    ${DIALOG} --yesno "Do you want any rsync options?" 15 55;
    selection="$?";

    case "${selection}" in\
        0)      if [ -f "${CFG_PATH}/sources/${source}/rsync_options" ];
                then
                    ${DIALOG} --inputbox "Put here any rsync options ya want.. but please be rsync conform.. otherwise your backup will fail. \`man rsync\` for details." 15 55\
                        $(cat "${CFG_PATH}/sources/${source}/rsync_options") 2>"${tmp}";
                    rsync_opts=$(cat "${tmp}");
                    echo "${rsync_opts}" > "${CFG_PATH}/sources/${source}/rsync_options";
                else
                    ${DIALOG} --inputbox "Put here any rsync options ya want.. but please be rsync conform.. otherwise your backup will fail. \`man rsync\` for details." 15 55 2>"${tmp}";
                    rsync_opts=$(cat "${tmp}");
                    echo "${rsync_opts}" > "${CFG_PATH}/sources/${source}/rsync_options";
                fi;
                return 0;;
        1)      if [ -f "${CFG_PATH}/sources/${source}/rsync_options" ];
                then
                    rm -f "${CFG_PATH}/sources/${source}/rsync_options";
                fi;
                return 0;;
        255)    echo "Canceled by user by pressing [ESC] key";;
    esac
    return 1;
}

src_edit_exclude() {
    ${DIALOG} --yesno "Do you want to exclude some directories of the backup?" 15 55;
    selection="$?";

    case "${selection}" in\
        0)      # if a exclude file exists, we keep the old data inside the new one.
                if [ -f "${CFG_PATH}/sources/${source}/exclude" ];
                then
                    cat "${CFG_PATH}/sources/${source}/exclude" > "${tmp}";
                else
                    echo "" > "${tmp}";
                fi;

                ${DIALOG} --msgbox "Now, this script open your default editor where you can add the directories and files separated by newlines." 15 55;
                "${EDITOR}" "${tmp}";
                cat "${tmp}" > "${CFG_PATH}/sources/${source}/exclude";
                return 0;;

        1)      if [ -f "${CFG_PATH}/sources/${source}/exclude" ];
                then
                    rm "${CFG_PATH}/sources/${source}/exclude";
                fi;
                return 0;
                ;;
        255)    echo "Canceled by user by pressing [ESC] key";;
    esac
    return 1;
}

src_edit_pre() {
    ${DIALOG} --yesno "Do you want a pre execution?" 15 55;
    selection="$?";
    
    case "${selection}" in\
        0)      if [ -f "${CFG_PATH}/sources/${source}/pre_exec" ];
                then
                    ${DIALOG} --inputbox "Please type here your shell compliant execution code:" 15 55 \
                        "$(cat "${CFG_PATH}/sources/${source}/pre_exec")" 2>"${tmp}";
                    pre=$(cat "${tmp}");
                    echo "${pre}" > "${CFG_PATH}/sources/${source}/pre_exec";
                else
                    ${DIALOG} --inputbox "Please type here your shell compliant execution code:" 15 55 2>"${tmp}";
                    pre=$(cat "${tmp}");
                    echo "${pre}" > "${CFG_PATH}/sources/${source}/pre_exec";
                fi;
                return 0;;

        1)      if [ -f "${CFG_PATH}/sources/${source}/pre_exec" ];
                then
                    rm -f "${CFG_PATH}/sources/${source}/pre_exec";
                fi;
                return 0;;

        255)    echo "Canceled by user by pressing [ESC] key";;
    esac
    return 1;
}

src_edit_post() {
    ${DIALOG} --yesno "Do you want a post execution?" 15 55;
    selection="$?";

    case "${selection}" in\
        0)      if [ -f "${CFG_PATH}/sources/${source}/post_exec" ];
                then
                    ${DIALOG} --inputbox "Please type here your shell compliant execution code:" 15 55 \
                        "$(cat "${CFG_PATH}/sources/${source}/post_exec")" 2>"${tmp}";
                    post=$(cat "${tmp}");
                    echo "${post}" > "${CFG_PATH}/sources/${source}/post_exec";
                else
                    ${DIALOG} --inputbox "Please type here your shell compliant execution code:" 15 55 2>"${tmp}";
                    post=$(cat "${tmp}");
                    echo "${post}" > "${CFG_PATH}/sources/${source}/post_exec";
                fi;
                return 0;;

        1)      if [ -f "${CFG_PATH}/sources/${source}/post_exec" ];
                then
                    rm -f "${CFG_PATH}/sources/${source}/post_exec";
                fi;
                return 0;;
                
        255)    echo "Canceled by user by pressing [ESC] key";;
    esac
    return 1;
}

src_edit_finmsg() {
    ${DIALOG} --msgbox "Successfully edited the source ${source}" 15 55;
    src_menu;
}

src_list() {
    ${DIALOG} --msgbox "$(ls "${CFG_PATH}/sources/")" 15 55;
    src_menu;
}

cleanup() {
    rm -r "${tmp}";
    echo "successfully cleaned. have a nice day.";
}

cfgpath;

# please leave this at the end of the script, it cleans up your system
# after runtime.
cleanup;
