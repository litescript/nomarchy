#!/usr/bin/env python3
"""Terminal TUI for managing bash aliases in ~/.bashrc"""

import re
import os
from pathlib import Path
from dataclasses import dataclass

from textual.app import App, ComposeResult
from textual.widgets import (
    Header,
    Footer,
    ListView,
    ListItem,
    Static,
    Input,
    Button,
    Label,
)
from textual.containers import Container, Horizontal, Vertical
from textual.screen import ModalScreen
from textual.binding import Binding


BASHRC_PATH = Path.home() / ".bashrc"
ALIAS_PATTERN = re.compile(r"^alias\s+([^=]+)=['\"]?(.+?)['\"]?\s*$")


@dataclass
class Alias:
    """Represents a bash alias."""
    name: str
    command: str
    line_number: int  # Line number in .bashrc (-1 for new aliases)

    def to_bash(self) -> str:
        """Convert to bash alias syntax."""
        # Use double quotes if command contains single quotes, else single quotes
        if "'" in self.command and '"' not in self.command:
            return f'alias {self.name}="{self.command}"'
        return f"alias {self.name}='{self.command}'"


def parse_bashrc() -> tuple[list[str], list[Alias]]:
    """Parse .bashrc and extract aliases."""
    lines = []
    aliases = []

    if BASHRC_PATH.exists():
        with open(BASHRC_PATH, "r") as f:
            lines = f.readlines()

        for i, line in enumerate(lines):
            stripped = line.strip()
            match = ALIAS_PATTERN.match(stripped)
            if match:
                name, command = match.groups()
                # Clean up trailing quote if present
                command = command.rstrip("'\"")
                aliases.append(Alias(name=name, command=command, line_number=i))

    return lines, aliases


def save_bashrc(original_lines: list[str], aliases: list[Alias]) -> None:
    """Save aliases back to .bashrc, preserving non-alias content."""
    # Build a set of line numbers that had aliases
    original_alias_lines = {a.line_number for a in aliases if a.line_number >= 0}

    # Start with original lines, removing old alias lines
    new_lines = []
    alias_section_start = -1

    for i, line in enumerate(original_lines):
        if i in original_alias_lines:
            if alias_section_start == -1:
                alias_section_start = len(new_lines)
            continue  # Skip old alias lines
        new_lines.append(line)

    # Find the "# --- Custom Aliases ---" marker or insert after comments
    insert_pos = alias_section_start if alias_section_start >= 0 else len(new_lines)

    for i, line in enumerate(new_lines):
        if "# --- Custom Aliases ---" in line:
            insert_pos = i + 1
            break

    # Insert all aliases at the insert position
    alias_lines = [a.to_bash() + "\n" for a in aliases]
    new_lines = new_lines[:insert_pos] + alias_lines + new_lines[insert_pos:]

    # Write back
    with open(BASHRC_PATH, "w") as f:
        f.writelines(new_lines)


class AliasItem(ListItem):
    """A list item representing an alias."""

    def __init__(self, alias: Alias) -> None:
        super().__init__()
        self.alias = alias

    def compose(self) -> ComposeResult:
        yield Static(f"[bold cyan]{self.alias.name}[/] = [dim]{self.alias.command}[/]")


class EditModal(ModalScreen[Alias | None]):
    """Modal for adding/editing an alias."""

    CSS = """
    EditModal {
        align: center middle;
    }

    #dialog {
        width: 70;
        height: auto;
        border: thick $primary;
        background: $surface;
        padding: 1 2;
    }

    #dialog Label {
        margin-bottom: 1;
    }

    #dialog Input {
        margin-bottom: 1;
    }

    #buttons {
        margin-top: 1;
        align: center middle;
    }

    #buttons Button {
        margin: 0 1;
    }
    """

    def __init__(self, alias: Alias | None = None) -> None:
        super().__init__()
        self.editing_alias = alias

    def compose(self) -> ComposeResult:
        title = "Edit Alias" if self.editing_alias else "Add Alias"
        name_val = self.editing_alias.name if self.editing_alias else ""
        cmd_val = self.editing_alias.command if self.editing_alias else ""

        with Vertical(id="dialog"):
            yield Label(f"[bold]{title}[/]")
            yield Label("Name:")
            yield Input(value=name_val, id="name_input", placeholder="alias name")
            yield Label("Command:")
            yield Input(value=cmd_val, id="cmd_input", placeholder="command to run")
            with Horizontal(id="buttons"):
                yield Button("Save", variant="primary", id="save")
                yield Button("Cancel", variant="default", id="cancel")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "save":
            name = self.query_one("#name_input", Input).value.strip()
            cmd = self.query_one("#cmd_input", Input).value.strip()

            if name and cmd:
                line_num = self.editing_alias.line_number if self.editing_alias else -1
                self.dismiss(Alias(name=name, command=cmd, line_number=line_num))
            else:
                self.notify("Name and command are required", severity="error")
        else:
            self.dismiss(None)

    def on_input_submitted(self, event: Input.Submitted) -> None:
        """Handle Enter key in inputs."""
        if event.input.id == "name_input":
            self.query_one("#cmd_input", Input).focus()
        else:
            self.query_one("#save", Button).press()


class ConfirmModal(ModalScreen[bool]):
    """Modal for confirming deletion."""

    CSS = """
    ConfirmModal {
        align: center middle;
    }

    #dialog {
        width: 50;
        height: auto;
        border: thick $error;
        background: $surface;
        padding: 1 2;
    }

    #buttons {
        margin-top: 1;
        align: center middle;
    }

    #buttons Button {
        margin: 0 1;
    }
    """

    def __init__(self, alias_name: str) -> None:
        super().__init__()
        self.alias_name = alias_name

    def compose(self) -> ComposeResult:
        with Vertical(id="dialog"):
            yield Label(f"[bold]Delete alias '[cyan]{self.alias_name}[/]'?[/]")
            with Horizontal(id="buttons"):
                yield Button("Delete", variant="error", id="confirm")
                yield Button("Cancel", variant="default", id="cancel")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(event.button.id == "confirm")


class AliasManagerApp(App):
    """Main TUI application for managing bash aliases."""

    CSS = """
    Screen {
        layout: grid;
        grid-size: 1;
        grid-rows: 1fr auto;
    }

    #main {
        height: 100%;
    }

    #list-container {
        height: 100%;
        border: solid $primary;
        padding: 0 1;
    }

    #detail-panel {
        height: auto;
        min-height: 5;
        border: solid $secondary;
        padding: 1;
        margin-top: 1;
    }

    ListView {
        height: 100%;
    }

    ListItem {
        padding: 0 1;
    }

    ListItem:hover {
        background: $primary-darken-2;
    }

    .selected-info {
        text-style: bold;
    }
    """

    BINDINGS = [
        Binding("a", "add_alias", "Add"),
        Binding("e", "edit_alias", "Edit"),
        Binding("d", "delete_alias", "Delete"),
        Binding("s", "save", "Save"),
        Binding("r", "reload", "Reload"),
        Binding("q", "quit", "Quit"),
        Binding("escape", "quit", "Quit", show=False),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.original_lines: list[str] = []
        self.aliases: list[Alias] = []
        self.modified = False

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Container(id="main"):
            with Vertical(id="list-container"):
                yield ListView(id="alias-list")
            yield Static(id="detail-panel")
        yield Footer()

    def on_mount(self) -> None:
        self.title = "Bash Alias Manager"
        self.sub_title = str(BASHRC_PATH)
        self.load_aliases()

    def load_aliases(self) -> None:
        """Load aliases from .bashrc."""
        self.original_lines, self.aliases = parse_bashrc()
        self.refresh_list()
        self.modified = False

    def refresh_list(self) -> None:
        """Refresh the alias list display."""
        list_view = self.query_one("#alias-list", ListView)
        list_view.clear()

        for alias in sorted(self.aliases, key=lambda a: a.name.lower()):
            list_view.append(AliasItem(alias))

        self.update_detail_panel()

    def update_detail_panel(self) -> None:
        """Update the detail panel with selected alias info."""
        panel = self.query_one("#detail-panel", Static)
        list_view = self.query_one("#alias-list", ListView)

        if list_view.highlighted_child and isinstance(list_view.highlighted_child, AliasItem):
            alias = list_view.highlighted_child.alias
            modified_marker = " [yellow]*[/]" if self.modified else ""
            panel.update(
                f"[bold cyan]{alias.name}[/]{modified_marker}\n"
                f"[dim]Command:[/] {alias.command}"
            )
        else:
            panel.update("[dim]No alias selected[/]")

    def on_list_view_highlighted(self, event: ListView.Highlighted) -> None:
        self.update_detail_panel()

    def get_selected_alias(self) -> Alias | None:
        """Get the currently selected alias."""
        list_view = self.query_one("#alias-list", ListView)
        if list_view.highlighted_child and isinstance(list_view.highlighted_child, AliasItem):
            return list_view.highlighted_child.alias
        return None

    def action_add_alias(self) -> None:
        """Open modal to add a new alias."""
        def on_result(result: Alias | None) -> None:
            if result:
                self.aliases.append(result)
                self.modified = True
                self.refresh_list()
                self.notify(f"Added alias '{result.name}'")

        self.push_screen(EditModal(), on_result)

    def action_edit_alias(self) -> None:
        """Open modal to edit selected alias."""
        alias = self.get_selected_alias()
        if not alias:
            self.notify("No alias selected", severity="warning")
            return

        def on_result(result: Alias | None) -> None:
            if result:
                # Find and update the alias
                for i, a in enumerate(self.aliases):
                    if a.line_number == alias.line_number and a.name == alias.name:
                        self.aliases[i] = result
                        break
                self.modified = True
                self.refresh_list()
                self.notify(f"Updated alias '{result.name}'")

        self.push_screen(EditModal(alias), on_result)

    def action_delete_alias(self) -> None:
        """Delete the selected alias."""
        alias = self.get_selected_alias()
        if not alias:
            self.notify("No alias selected", severity="warning")
            return

        def on_result(confirmed: bool) -> None:
            if confirmed:
                self.aliases = [a for a in self.aliases if not (
                    a.name == alias.name and a.line_number == alias.line_number
                )]
                self.modified = True
                self.refresh_list()
                self.notify(f"Deleted alias '{alias.name}'")

        self.push_screen(ConfirmModal(alias.name), on_result)

    def action_save(self) -> None:
        """Save changes to .bashrc."""
        if not self.modified:
            self.notify("No changes to save")
            return

        try:
            save_bashrc(self.original_lines, self.aliases)
            self.modified = False
            self.update_detail_panel()
            self.notify("Saved to ~/.bashrc", severity="information")
        except Exception as e:
            self.notify(f"Error saving: {e}", severity="error")

    def action_reload(self) -> None:
        """Reload aliases from .bashrc."""
        if self.modified:
            self.notify("Discarding unsaved changes", severity="warning")
        self.load_aliases()
        self.notify("Reloaded from ~/.bashrc")

    def action_quit(self) -> None:
        """Quit the application."""
        if self.modified:
            self.notify("Warning: Unsaved changes will be lost!", severity="warning")
            # Could add a confirm dialog here, but for now just warn
        self.exit()


def main():
    app = AliasManagerApp()
    app.run()


if __name__ == "__main__":
    main()
