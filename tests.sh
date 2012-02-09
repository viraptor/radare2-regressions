#!/do/not/execute

# Copyright (C) 2011       pancake<nopcode.org>
# Copyright (C) 2011-2012  Edd Barrett <vext01@gmail.com>
# Copyright (C) 2012       Simon Ruderich <simon@ruderich.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


run_test() {
    if [ -z "${R2}" ]; then
        R2=$(which radare2)
    fi

    # Set by run_tests.sh if all tests are run - otherwise get it from test
    # name.
    if [ -z "${TEST_NAME}" ]; then
        TEST_NAME=$(basename "$0" | sed 's/\.sh$//')
    fi

    NAME_TMP="${TEST_NAME}"
    [ -n "${NAME}" ]     && NAME_TMP="${NAME_TMP}: ${NAME}"
    [ -n "${VALGRIND}" ] && NAME_TMP="${NAME_TMP} (valgrind)"
    printf "%-40s" "${NAME_TMP}"

    # Check required variables.
    if [ -z "${FILE}" ]; then
        test_failed "FILE missing!"
        test_reset
        return
    fi
    if [ -z "${CMDS}" ]; then
        test_failed "CMDS missing!"
        test_reset
        return
    fi
    # ${EXPECT} can be empty. Don't check it.

    # Verbose mode is always used if only a single test is run.
    if [ -z "${R2_SOURCED}" ]; then
        VERBOSE=1
    fi

    mkdir -p ../tmp
    TMP_RAD=$(mktemp "../tmp/${TEST_NAME}-rad.XXXXXX")
    TMP_OUT=$(mktemp "../tmp/${TEST_NAME}-out.XXXXXX")
    TMP_VAL=$(mktemp "../tmp/${TEST_NAME}-val.XXXXXX")
    TMP_EXP=$(mktemp "../tmp/${TEST_NAME}-exp.XXXXXX")

    # No colors and no user configs.
    R2ARGS="${R2} -e scr.color=0 -N -q -i ${TMP_RAD} ${ARGS} ${FILE} > ${TMP_OUT} 2>&1"
    R2CMD=
    # Valgrind to detect memory corruption.
    if [ -n "${VALGRIND}" ]; then
        R2CMD="valgrind --error-exitcode=47 --log-file=${TMP_VAL}"
    fi
    R2CMD="echo q | ${R2CMD} ${R2ARGS}"

    # Put expected outcome and program to run in files and run the test.
    echo "${CMDS}"   > ${TMP_RAD}
    echo "${EXPECT}" > ${TMP_EXP}
    if [ -n "${VERBOSE}" ]; then
        echo "${R2CMD}"
    fi
    eval "${R2CMD}"
    CODE=$?

    if [ -n "${R2_SOURCED}" ]; then
        TESTS_RUN=$(( TESTS_RUN + 1 ))
    fi

    # ${FILTER} can be used to filter out random results to create stable
    # tests.
    if [ -n "${FILTER}" ]; then
        eval "cat ${TMP_OUT} | ${FILTER} > ${TMP_OUT}.filter"
        mv "${TMP_OUT}.filter" "${TMP_OUT}"
    fi

    # Check if radare2 exited with correct exit code.
    if [ -n "${EXITCODE}" ]; then
        if [ ${CODE} -eq "${EXITCODE}" ]; then
            CODE=0
            EXITCODE=
        else
            EXITCODE=${CODE}
        fi
    fi

    if [ ${CODE} -eq 47 ]; then
        test_failed "valgrind error"
        if [ -n "${VERBOSE}" ]; then
            cat "${TMP_VAL}"
            echo
        fi

    elif [ -n "${EXITCODE}" ]; then
        test_failed "wrong exit code: ${EXITCODE}"

    elif [ ! ${CODE} -eq 0 ]; then
        test_failed "radare2 crashed"
        if [ -n "${VERBOSE}" ]; then
            cat "${TMP_OUT}"
            echo
        fi

    elif [ "$(cat "${TMP_OUT}")" = "${EXPECT}" ]; then
        test_success

    else
        test_failed "unexpected outcome"
        if [ -n "${VERBOSE}" ]; then
            diff -u ${TMP_EXP} ${TMP_OUT}
            echo
        fi
    fi

    rm -f "${TMP_RAD}" "${TMP_OUT}" "${TMP_VAL}" "${TMP_EXP}"

    # Reset most variables in case the next test script doesn't set them.
    test_reset
}

test_reset() {
    NAME=
    FILE=
    ARGS=
    CMDS=
    EXPECT=
    FILTER=
    EXITCODE=
    BROKEN=
}

test_success() {
    if [ -z "${BROKEN}" ]; then
        print_success "OK "
    else
        print_fixed "FIXED"
    fi

    if [ -n "${R2_SOURCED}" ]; then
        if [ -z "${BROKEN}" ]; then
            TESTS_SUCCESS=$(( TESTS_SUCCESS + 1 ))
        else
            TESTS_FIXED=$(( TESTS_FIXED + 1 ))
        fi
    fi
}
test_failed() {
    if [ -z "${BROKEN}" ]; then
        print_failed "FAIL ($1)"
    else
        print_failed "BROKEN ($1)"
    fi

    if [ -n "${R2_SOURCED}" ]; then
        if [ -z "${BROKEN}" ]; then
            TESTS_FAILED=$(( TESTS_FAILED + 1 ))
        else
            TESTS_BROKEN=$(( TESTS_BROKEN + 1 ))
        fi
    fi
}

print_success() {
    printf "%b" "\033[32m${*}\033[0m\n"
}
print_failed() {
    printf "%b" "\033[31m${*}\033[0m\n"
}
print_fixed() {
    printf "%b" "\033[33m${*}\033[0m\n"
}
