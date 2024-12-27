# save the current buffer to its file as root using `sudo`
# prompt and pass the user password to sudo if not cached

# toggle fprint mode
declare-option bool fprint_mode false

define-command -hidden sudo-write-cached %{
    # easy case: the password was already cached, so we don't need any tricky handling
    evaluate-commands -save-regs f %{
        set-register f %sh{ mktemp -t XXXXXX }
        write! %reg{f}
        evaluate-commands %sh{
            sudo -n -- dd if="$kak_main_reg_f" of="$kak_buffile" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "edit!"
            else
                echo 'fail "Unknown failure"'
            fi
            rm -f "$kak_main_reg_f"
        }
    }
}

define-command -hidden sudo-write-prompt %{
    prompt -password 'Password:' %{
        evaluate-commands -save-regs r %{
            evaluate-commands -draft -save-regs 'tf|"' %{
                set-register t %val{buffile}
                set-register f %sh{ mktemp -t XXXXXX }
                write! %reg{f}

                # write the password in a buffer in order to pass it through STDIN to sudo
                # somewhat dangerous, but better than passing the password
                # through the shell scope's environment or interpolating it inside the shell string
                # 'exec |' is pretty much the only way to pass data over STDIN
                edit -scratch '*sudo-password-tmp*'
                set-register '"' "%val{text}"
                execute-keys <a-P>
                set-register | %{
                    sudo -S -- dd if="$kak_main_reg_f" of="$kak_main_reg_t" > /dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        printf 'edit!'
                    else
                        printf 'fail "Incorrect password?"'
                    fi
                    rm -f "$kak_main_reg_f"
                }
                execute-keys '|<ret>'
                execute-keys -save-regs '' '%"ry'
                delete-buffer! '*sudo-password-tmp*'
            }
            evaluate-commands %reg{r}
        }
    }
}

define-command -hidden sudo-write-fprint %{
    evaluate-commands -save-regs f %{
        set-register f %sh{ mktemp -t XXXXXX }
        write! %reg{f}
        evaluate-commands %sh{
            # if fprint is enabled we use -S to bypass the password prompt
            sudo -S -- dd if="$kak_main_reg_f" of="$kak_buffile" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "edit!"
            else
                echo 'fail "Unknown failure"'
            fi
            rm -f "$kak_main_reg_f"
        }
    }
}


define-command sudo-write -docstring "Write the content of the buffer using sudo" %{
    evaluate-commands %sh{
        # tricky posix-way of getting the first character of a variable
        # no subprocess!
        if [ "${kak_buffile%"${kak_buffile#?}"}" != "/" ]; then
            # not entirely foolproof as a scratch buffer may start with '/', but good enough
            echo 'fail "Not a file"'
            exit
        # check if fprint is enabled
        elif "$kak_opt_fprint_mode"; then
            echo sudo-write-fprint
        # check if the password is cached
        elif sudo -n true > /dev/null 2>&1; then
            echo sudo-write-cached
        else
            echo sudo-write-prompt
        fi
    }
}

# SAME AS ABOVE WITH 'QUIT' APPENEDED

define-command sudo-write-quit -docstring "Write the content of the buffer using sudo, then quit" %{
    evaluate-commands %sh{
        if [ "${kak_buffile%"${kak_buffile#?}"}" != "/" ]; then
            echo 'fail "Not a file"'
            exit
        elif "$kak_opt_fprint_mode"; then
            echo "sudo-write-fprint"
        elif sudo -n true > /dev/null 2>&1; then
            echo "sudo-write-cached"
        else
            echo "sudo-write-prompt"
        fi
        echo "quit"
    }
}

