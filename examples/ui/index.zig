use @import("ui.zig");

const std = @import("std");

extern fn onClosing(w: ?*uiWindow, data: ?*c_void) c_int {
    uiQuit();
    return 1;
}

extern fn onShouldQuit(data: ?*c_void) c_int {
    var win = @ptrCast(*uiWindow, data);
    uiControlDestroy(@ptrCast(*uiControl, @alignCast(4, win)));
    return 1;
}

fn makeBasicControlsPage() *uiControl {
    var vbox = uiNewVerticalBox();
    uiBoxSetPadded(vbox, 1);

    var hbox = uiNewHorizontalBox();
    uiBoxSetPadded(hbox, 1);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, hbox)), 0);

    uiBoxAppend(hbox, @ptrCast(*uiControl, @alignCast(4, uiNewButton(c"Button"))), 0);
    uiBoxAppend(hbox, @ptrCast(*uiControl, @alignCast(4, uiNewCheckbox(c"Checkbox"))), 0);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, uiNewLabel(c"This is a label. Right now, labels can only span one line."))), 0);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, uiNewHorizontalSeparator())), 0);

    var group = uiNewGroup(c"Entries");
    uiGroupSetMargined(group, 1);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, group)), 1);

    var entryForm = uiNewForm();
    uiFormSetPadded(entryForm, 1);
    uiGroupSetChild(group, @ptrCast(*uiControl, @alignCast(4, entryForm)));

    uiFormAppend(entryForm, c"Entry", @ptrCast(*uiControl, @alignCast(4, uiNewEntry())), 0);
    uiFormAppend(entryForm, c"Password Entry", @ptrCast(*uiControl, @alignCast(4, uiNewPasswordEntry())), 0);
    uiFormAppend(entryForm, c"Search Entry", @ptrCast(*uiControl, @alignCast(4, uiNewSearchEntry())), 0);
    uiFormAppend(entryForm, c"Multiline Entry", @ptrCast(*uiControl, @alignCast(4, uiNewMultilineEntry())), 1);
    uiFormAppend(entryForm, c"Multiline Entry No Wrap", @ptrCast(*uiControl, @alignCast(4, uiNewNonWrappingMultilineEntry())), 1);

    return @ptrCast(*uiControl, @alignCast(4, vbox));
}

var spinbox: *uiSpinbox = undefined;
var slider: *uiSlider = undefined;
var pbar: *uiProgressBar = undefined;

extern fn onSpinboxChanged(s: ?*uiSpinbox, data: ?*c_void) void {
    uiSliderSetValue(slider, uiSpinboxValue(s));
    uiProgressBarSetValue(pbar, uiSpinboxValue(s));
}

extern fn onSliderChanged(s: ?*uiSlider, data: ?*c_void) void {
    uiSpinboxSetValue(spinbox, uiSliderValue(s));
    uiProgressBarSetValue(pbar, uiSliderValue(s));
}

fn makeNumbersPage() *uiControl {
    var hbox = uiNewHorizontalBox();
    uiBoxSetPadded(hbox, 1);

    var group = uiNewGroup(c"Numbers");
    uiGroupSetMargined(group, 1);
    uiBoxAppend(hbox, @ptrCast(*uiControl, @alignCast(4, group)), 1);

    var vbox = uiNewVerticalBox();
    uiBoxSetPadded(vbox, 1);
    uiGroupSetChild(group, @ptrCast(*uiControl, @alignCast(4, vbox)));

    spinbox = uiNewSpinbox(0, 100).?;
    slider = uiNewSlider(0, 100).?;
    pbar = uiNewProgressBar().?;
    uiSpinboxOnChanged(spinbox, onSpinboxChanged, null);
    uiSliderOnChanged(slider, onSliderChanged, null);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, spinbox)), 0);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, slider)), 0);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, pbar)), 0);

    var ip = uiNewProgressBar();
    uiProgressBarSetValue(ip, -1);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, ip)), 0);

    group = uiNewGroup(c"Lists");
    uiGroupSetMargined(group, 1);
    uiBoxAppend(hbox, @ptrCast(*uiControl, @alignCast(4, group)), 1);

    vbox = uiNewVerticalBox();
    uiBoxSetPadded(vbox, 1);
    uiGroupSetChild(group, @ptrCast(*uiControl, @alignCast(4, vbox)));

    var cbox = uiNewCombobox();
    uiComboboxAppend(cbox, c"Combobox Item 1");
    uiComboboxAppend(cbox, c"Combobox Item 2");
    uiComboboxAppend(cbox, c"Combobox Item 3");
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, cbox)), 0);

    var ecbox = uiNewEditableCombobox();
    uiEditableComboboxAppend(ecbox, c"Editable Item 1");
    uiEditableComboboxAppend(ecbox, c"Editable Item 2");
    uiEditableComboboxAppend(ecbox, c"Editable Item 3");
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, ecbox)), 0);

    var rb = uiNewRadioButtons();
    uiRadioButtonsAppend(rb, c"Radio Button 1");
    uiRadioButtonsAppend(rb, c"Radio Button 2");
    uiRadioButtonsAppend(rb, c"Radio Button 3");
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, rb)), 0);

    return @ptrCast(*uiControl, @alignCast(4, hbox));
}

var mainwin: *uiWindow = undefined;

extern fn onOpenFileClicked(b: ?*uiButton, data: ?*c_void) void {
    var entry: *uiEntry = @ptrCast(*uiEntry, data.?);
    var filename: [*]u8 = undefined;

    filename = uiOpenFile(mainwin) orelse {
        uiEntrySetText(entry, c"(cancelled)");
        return;
    };

    uiEntrySetText(entry, filename);
    uiFreeText(filename);
}

extern fn onSaveFileClicked(b: ?*uiButton, data: ?*c_void) void {
    var entry: *uiEntry = @ptrCast(*uiEntry, data.?);
    var filename: [*]u8 = undefined;

    filename = uiSaveFile(mainwin) orelse {
        uiEntrySetText(entry, c"(cancelled)");
        return;
    };

    uiEntrySetText(entry, filename);
    uiFreeText(filename);
}

extern fn onMsgBoxClicked(b: ?*uiButton, data: ?*c_void) void {
    uiMsgBox(mainwin, c"This is a normal message box.", c"More detailed information can be shown here.");
}

extern fn onMsgBoxErrorClicked(b: ?*uiButton, data: ?*c_void) void {
    uiMsgBoxError(mainwin, c"This message box describes an error.", c"More detailed information can be shown here.");
}

fn makeDataChoosersPage() *uiControl {
    var hbox = uiNewHorizontalBox();
    uiBoxSetPadded(hbox, 1);

    var vbox = uiNewVerticalBox();
    uiBoxSetPadded(vbox, 1);
    uiBoxAppend(hbox, @ptrCast(*uiControl, @alignCast(4, vbox)), 0);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, uiNewDatePicker())), 0);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, uiNewTimePicker())), 0);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, uiNewDateTimePicker())), 0);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, uiNewFontButton())), 0);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, uiNewColorButton())), 0);
    uiBoxAppend(hbox, @ptrCast(*uiControl, @alignCast(4, uiNewVerticalSeparator())), 0);

    vbox = uiNewVerticalBox();
    uiBoxSetPadded(vbox, 1);
    uiBoxAppend(hbox, @ptrCast(*uiControl, @alignCast(4, vbox)), 1);

    var grid = uiNewGrid();
    uiGridSetPadded(grid, 1);
    uiBoxAppend(vbox, @ptrCast(*uiControl, @alignCast(4, grid)), 0);

    var button = uiNewButton(c"Open File");
    var entry = uiNewEntry().?;
    uiEntrySetReadOnly(entry, 1);
    uiButtonOnClicked(button, onOpenFileClicked, @ptrCast(*c_void, entry));
    uiGridAppend(grid, @ptrCast(*uiControl, @alignCast(4, button)), 0, 0, 1, 1, 0, uiAlignFill, 0, uiAlignFill);
    uiGridAppend(grid, @ptrCast(*uiControl, @alignCast(4, entry)), 1, 0, 1, 1, 1, uiAlignFill, 0, uiAlignFill);

    button = uiNewButton(c"Save File");
    entry = uiNewEntry().?;
    uiEntrySetReadOnly(entry, 1);
    uiButtonOnClicked(button, onSaveFileClicked, @ptrCast(*c_void, entry));
    uiGridAppend(grid, @ptrCast(*uiControl, @alignCast(4, button)), 0, 1, 1, 1, 0, uiAlignFill, 0, uiAlignFill);
    uiGridAppend(grid, @ptrCast(*uiControl, @alignCast(4, entry)), 1, 1, 1, 1, 1, uiAlignFill, 0, uiAlignFill);

    var msggrid = uiNewGrid();
    uiGridSetPadded(msggrid, 1);
    uiGridAppend(grid, @ptrCast(*uiControl, @alignCast(4, msggrid)), 0, 2, 2, 1, 0, uiAlignCenter, 0, uiAlignStart);

    button = uiNewButton(c"Message Box");
    uiButtonOnClicked(button, onMsgBoxClicked, null);
    uiGridAppend(msggrid, @ptrCast(*uiControl, @alignCast(4, button)), 0, 0, 1, 1, 0, uiAlignFill, 0, uiAlignFill);

    button = uiNewButton(c"Error Box");
    uiButtonOnClicked(button, onMsgBoxErrorClicked, null);
    uiGridAppend(msggrid, @ptrCast(*uiControl, @alignCast(4, button)), 1, 0, 1, 1, 0, uiAlignFill, 0, uiAlignFill);

    return @ptrCast(*uiControl, @alignCast(4, hbox));
}

pub fn main() !void {
    // TODO: Zero options struct
    var options: uiInitOptions = undefined;

    var err = uiInit(&options);
    if (err != null) {
        std.debug.warn("error initializing libui: {}", err);
        uiFreeInitError(err);
        return error.InitFailed;
    }

    mainwin = uiNewWindow(c"libui Control Gallery", 640, 480, 1) orelse return error.NoWindow;
    uiWindowOnClosing(mainwin, onClosing, null);
    uiOnShouldQuit(onShouldQuit, @ptrCast(*c_void, mainwin));

    var tab = uiNewTab() orelse return error.NewTabFailed;
    uiWindowSetChild(mainwin, @ptrCast(*uiControl, @alignCast(4, tab)));
    uiWindowSetMargined(mainwin, 1);

    uiTabAppend(tab, c"Basic Controls", makeBasicControlsPage());
    uiTabSetMargined(tab, 0, 1);

    uiTabAppend(tab, c"Numbers and Lists", makeNumbersPage());
    uiTabSetMargined(tab, 1, 1);

    uiTabAppend(tab, c"Data Choosers", makeDataChoosersPage());
    uiTabSetMargined(tab, 2, 1);

    uiControlShow(@ptrCast(*uiControl, @alignCast(4, mainwin)));
    uiMain();
}