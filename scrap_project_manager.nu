#! /usr/bin/env nix-shell
#! nix-shell -i nu -p nushell gum
let CANCELED = $"(ansi dark_gray)Canceled(ansi reset)"

def choose [prompt: string] {
    let choices = $in
    let selection = $choices | input list $prompt -f
    $choices | enumerate | where item == $selection | get 0?.index
}

def align [] {
    let rows = $in
    let counts = $rows | each {|row|
        $row | each {|it|
            $it | str length
        }
    }
    
    let limits = 0..<($counts.0 | length) | each {|i|
        $counts | each {|row|
            $row | get $i
        } | math max
    }
    
    $rows | each {|row|
        $row | enumerate | each {|it|
            $it.item | fill -a left -c ' ' -w ($limits | get $it.index)
        } | str join
    }
}

def menu [projects: string] {
    loop {
        match ([
            "Open project",
            "New Project",
            "Exit",
        ] | choose "Select an action (esc to exit)") {
            0 => (open_project $projects)
            1 => (add_project $projects)
            2 => (exit 0)
            _ => (exit 0)
        }
    }
}

def open_project [projects_path: string] {
    let projects = open $projects_path
    if ($projects | length) == 0 {
        print $"(ansi yellow)No known projects, please add some first(ansi reset)"
        return
    }
    let proj = $projects | each {|it| [$"($it.name)" "    " $"(ansi dark_gray)($it.path)(ansi reset)"]} | align | choose "Select a project (esc to go back)"
    if $proj == null {
        print $CANCELED
        return
    }
    let project_data = $projects | get $proj
    $projects | drop nth $proj | prepend $project_data | save $projects_path -f

    open_folder ($projects | get $proj | get path)
}

def detect_ide [path: string] {
    cd $path
    if ("Cargo.nix" | path exists) { # Rust
        $"clion ($path)"
    } else if ("package.json" | path exists) { # NodeJS
        $"webstorm ($path)"
    } else if ("go.mod" | path exists) { # Go
        $"goland ($path)"
    } else if (glob "*.csproj" | length) > 0 { # C#
        $"rider ($path)"
    } else {
        # Fallback to VSCodium
        $"code ($path)"
    }
}

def open_folder [path: string] {
    cd $path

    # print $"Loading project ($path)"

    if ("spm_dev.sh" | path exists) {
        print "spm_dev.sh runner detected"
        run-external ($path | path join "spm_dev.sh")
        return
    }

    let ide_cmd = detect_ide $path
    let run_ide = $ide_cmd != null and (^gum confirm "Run IDE?" | complete | get exit_code) == 0

    if ("flake.nix" | path exists) { # flake.nix
        print "Nix Flake runner detected"

        if ("Cargo.nix" | path exists) { # Cargo.nix
            ^nix run github:cargo2nix/cargo2nix -- -o
        }

        if $run_ide {
            run-external "bash" "-c" $"nix develop --command ($ide_cmd) > /dev/null 2>&1 & disown"
        } else {
            ^nix develop
        }
    } else if ("shell.nix" | path exists) { # shell.nix
        print "Nix Shell runner detected"

        if $run_ide {
            run-external "bash" "-c" $'nix-shell shell.nix --run "($ide_cmd) > /dev/null 2>&1" & disown'
        } else {
            ^nix-shell
        }
    } else {
        if $run_ide {
            print "No runner detected, just launching IDE directly"
            run-external "bash" "-c" $"($ide_cmd) > /dev/null 2>&1 & disown"
        } else {
            print "No runner detected, and no ide is launched, what do you expect me to do? Booting up the bash"
            run-external "bash"
        }
    }
}

def add_project [projects_path: string] {
    let selection = ^gum file --file=0 --directory | complete
    if $selection.exit_code != 0 {
        print $CANCELED
        return
    }
    let selection = $selection.stdout | lines | first | path expand
    let projects = open $projects_path
    if ($projects | any { |it| ($it.path | path expand) == $selection }) {
        print $"(ansi red)Project with this path is already added(ansi reset)"
        return
    }
    let default_name = $selection | path basename
    print $"Project path: ($selection)"
    let input = ^gum input --placeholder $"($default_name)" --prompt "Project name: " | complete
    if ($input.exit_code != 0) {
        print $CANCELED
        return
    }
    let project_name = $input.stdout | lines | first
    let project_name = if $project_name == "" { $default_name } else { $project_name }

    let confirm = ^gum confirm $'Confirm adding project "($project_name)" at path "($selection)"' | complete
    if $confirm.exit_code != 0 {
        print $CANCELED
        return
    }
    $projects | prepend {name: $project_name path:$selection} | save $projects_path -f
    print $"(ansi lime)Project added succesfully(ansi reset)"
}

export def main [
    --projects (-p): string = "~/.scrap_project_manager.json" # Path to the projects.json
] {
    if (glob $projects | length) == 0 {
        [] | save $projects
    }
    menu $projects
    exit 0
}