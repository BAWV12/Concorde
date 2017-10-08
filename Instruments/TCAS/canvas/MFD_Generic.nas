# Generic Page switching cockpit display device.
# ---------------------------
# Richard Harrison: 2015-10-17 : rjh@zaretto.com
# ---------------------------
# I'm calling this a PFD as in Programmable Function Display.
# ---------------------------
# documentation: see http://wiki.flightgear.org/Canvas_MFD_Framework
# See FGAddon/Aircraft/F-15/Nasal/MPCD/MPCD_main.nas for an example usage
# ---------------------------
# This is but a straightforwards wrapper to provide the core logic that page switching displays require.
# Examples of Page switching displays
# * MFD
# * PFD
# * FMCS
# * F-15 MPCD

#
# Menu Item. There is a list of these for each page changing button per display page
# Parameters:
# menu_id : page change event id for this menu item. e.g. button number
# title   : Title Text (for display on the device)
# page    : Instance of page usually returned from PFD.addPage

var PFD_MenuItem =
{
    new : func (menu_id, title, page)
    {
		var obj = {parents : [PFD_MenuItem] };
        obj.page = page;
        obj.menu_id = menu_id;
        obj.title = title;
        return obj;
    },
        };

#
#
# Create a new PFD Page
# - related svg 
# - Title: Page title
# - SVG element for the page
# - Device to attach the page to

var PFD_Page =
{
	new : func (svg, title, layer_id, device)
    {
		var obj = {parents : [PFD_Page] };
        obj.title = title;
        obj.device = device;
        obj.layer_id = layer_id;
        obj.menus = [];
        obj.svg = svg.getElementById(layer_id);
        if(obj.svg == nil)
            printf("PFD_Device: Error loading %s: svg layer %s ",title, layer_id);

        return obj;
    },

    #
    # Makes a page visible. 
    # It is the responsibility of the caller to manage the visibility of pages - i.e. to 
    # make a page that is currenty visible not visible before making a new page visible,
    # however more than one page could be visible - but only one set of menu buttons can be active
    # so if two pages are visible (e.g. an overlay) then when the overlay removed it would be necessary
    # to call setVisible on the base page to ensure that the menus are seutp
    setVisible : func(vis)
    {
        if(me.svg != nil)
            me.svg.setVisible(vis);

        if (vis)
            me.ondisplay();
        else
            me.offdisplay();
    },

    #
    # Perform action when button is pushed
    notifyButton : func(button_id) 
    {        foreach(var mi; me.menus)
             {
                 if (mi.menu_id == button_id)
                 {
                     me.device.selectPage(mi.page);
                     break;
                 }
             }
    },

    # 
    # Add an item to a menu
    # Params:
    #  menu button id (that is set in controls/PFD/button-pressed by the model)
    #  title of the menu for the label
    #  page that will be selected when pressed
    # 
    # The corresponding menu for the selected page will automatically be loaded
    addMenuItem : func(menu_id, title, page)
    {
        var nm = PFD_MenuItem.new(menu_id, title, page);
        append(me.menus, nm);
        return nm;
    },

    # base method for update; this can be overriden per page instance to provide update of the
    # elements on display (e.g. to display updated properties)
    update : func(notification=nil)
    {
    },

    #
    # notify the page that it is being displayed. use to load any static framework or perform one
    # time initialisation
    ondisplay : func
    {
    },

    #
    # notify the page that it is going off display; use to clean up any created elements or perform
    # any other required functions
    offdisplay : func
    {
    },
};


#
# Container device for pages.
var PFD_Device =
{
# - svg is the page elements from the svg.
# - num_menu_buttons is the Number of menu buttons; starting from the bottom left then right, then top, then left.
# - button prefix (e.g MI_) is the prefix of the labels in the SVG for the menu boxes.
# - _canvas is the canvas group.
#NOTE:
# This does not actually create the canvas elements, or parse the SVG, that would typically be done in 
# a higher level class that contains an instance of this class.
# see: http://wiki.flightgear.org/Canvas_MFD_Framework
    new : func(svg, num_menu_buttons, button_prefix, _canvas)
    {
		var obj = {parents : [PFD_Device] };
        obj.svg = svg;
        obj.canvas = _canvas;
        obj.current_page = nil;
        obj.pages = [];
        obj.page_index = {};
        obj.buttons = setsize([], num_menu_buttons);

        for(var idx = 0; idx < num_menu_buttons; idx += 1)
        {
            var label_name = sprintf(button_prefix~"%d",idx);
            var msvg = obj.svg.getElementById(label_name);
            if (msvg == nil)
                printf("PFD_Device: Failed to load  %s",label_name);
            else
            {
                obj.buttons[idx] = msvg;
                obj.buttons[idx].setText(sprintf("M",idx));
            }
        }
        return obj;
    },
    #
    # called when a button is pushed - connecting the property to this method is implemented in the outer class
    notifyButton : func(button_id)
    {
        #
        # by convention the buttons we have are 0 based; however externally 0 is used
        # to indicate no button pushed.
        if (button_id > 0)
        {
            button_id = button_id - 1;
            if (me.current_page != nil)
            {
                me.current_page.notifyButton(button_id);
            }
            else
                printf("PFD_Device: Could not locate page for button ",button_id);
        }
    },
    #
    #
    # add a page to the device.
    # - page title.
    # - svg element id
    addPage : func(title, layer_id)
    {
        var np = PFD_Page.new(me.svg, title, layer_id, me);
        append(me.pages, np);
        me.page_index[layer_id] = np;
        np.setVisible(0);
        return np;
    },
    #
    # manage the update of the currently selected page
    update : func(notification=nil)
    {
        if (me.current_page != nil)
            me.current_page.update(notification);
    },
    #
    # Change to display the selected page.
    # - the page object method controls the visibility
    selectPage : func(p)
    {
        if (me.current_page != nil)
            me.current_page.setVisible(0);
        if (me.buttons != nil)
        {
            foreach(var mb ; me.buttons)
                if (mb != nil)
                    mb.setVisible(0);

            foreach(var mi ; p.menus)
            {
                if (me.buttons[mi.menu_id] != nil)
                {
                    me.buttons[mi.menu_id].setText(mi.title);
                    me.buttons[mi.menu_id].setVisible(1);
                }
                else
                    printf("PFD_device: Menu for button not found. Menu ID '%s'",mi.menu_id);
            }
        }
        p.setVisible(1);
        me.current_page = p;
    },
    #
    # ensure that the menus are display correctly for the current page.
    updateMenus : func
    {
        foreach(var mi ; me.current_page.menus)
        {
            if (me.buttons[mi.menu_id] != nil)
            {
                me.buttons[mi.menu_id].setText(mi.title);
                me.buttons[mi.menu_id].setVisible(1);
            }
            else
                printf("No corresponding item '%s'",mi.menu_id);
        }
    },
};

var PFD_NavDisplay =
{
#
# Instantiate parameters:
# 1. pfd_device (instance of PFD_Device)
# 2. instrument display ident (e.g. mfd-map, or mfd-map-left mfd-map-right for multiple displays)
#    (this is used to map to the property tree)
# 3. layer_id: main layer  in the SVG
# 4. nd_group_ident : group (usually within the main layer) to place the NavDisplay
# 5. switches - used to connect the property tree to the nav display. see the canvas nav display
#    documentation
	new : func (pfd_device, title, instrument_ident, layer_id, nd_group_ident, switches=nil, map_style="Boeing")
    {
		var obj = pfd_device.addPage(title, layer_id);

        # if no switches given then use a default set.
        if (switches != nil)
            obj.switches = switches;
        else
            obj.switches = {
                'toggle_range':         { path: '/inputs/range-nm',    value: 50,    type: 'INT' },
                'toggle_weather':       { path: '/inputs/wxr',         value: 0,     type: 'BOOL' },
                'toggle_airports':      { path: '/inputs/arpt',        value: 1,     type: 'BOOL' },
                'toggle_stations':      { path: '/inputs/sta',         value: 1,     type: 'BOOL' },
                'toggle_waypoints':     { path: '/inputs/wpt',         value: 1,     type: 'BOOL' },
                'toggle_position':      { path: '/inputs/pos',         value: 0,     type: 'BOOL' },
                'toggle_data':          { path: '/inputs/data',        value: 0,     type: 'BOOL' },
                'toggle_terrain':       { path: '/inputs/terr',        value: 0,     type: 'BOOL' },
                'toggle_traffic':       { path: '/inputs/tfc',         value: 1,     type: 'BOOL' },
                'toggle_centered':      { path: '/inputs/nd-centered', value: 1,     type: 'BOOL' },
                'toggle_lh_vor_adf':    { path: '/inputs/lh-vor-adf',  value: 1,     type: 'INT' },
                'toggle_rh_vor_adf':    { path: '/inputs/rh-vor-adf',  value: 1,     type: 'INT' },
                'toggle_display_mode':  { path: '/mfd/display-mode',   value: 'MAP', type: 'STRING' },
                'toggle_display_type':  { path: '/mfd/display-type',   value: 'LCD', type: 'STRING' },
                'toggle_true_north':    { path: '/mfd/true-north',     value: 0,     type: 'BOOL' },
                'toggle_rangearc':      { path: '/mfd/rangearc',       value: 0,     type: 'BOOL' },
                'toggle_track_heading': { path: '/hdg-trk-selected',   value: 1,     type: 'BOOL' },
            };

        obj.nd_initialised = 0;
        obj.nd_placeholder_ident = nd_group_ident;
        obj.nd_ident = instrument_ident;
        obj.pfd_device = pfd_device;

        obj.nd_init = func
        {
            me.ND = canvas.NavDisplay;
            if (!me.nd_initialised)
            {
                me.nd_initialised = 1;
    
                me.NDCpt = me.ND.new("instrumentation/"~me.nd_ident, me.switches,map_style);
    
                me.group = me.pfd_device.svg.getElementById(me.nd_placeholder_ident);
                me.group.setScale(0.39,0.45);
                me.group.setTranslation(45,0);
                me.NDCpt.newMFD(me.group, pfd_device.canvas);
            }
            me.NDCpt.update();
        };
        #
        # Method overrides
        #-----------------------------------------------
        # Called when the page goes on display - need to delay initialization of the NavDisplay until later (it fails
        # if done too early).
        # NOTE: This causes a display "wobble" the first time on display as resizing happens. I've seen similar things
        #       happen on real avionics (when switched on) so it's not necessarily unrealistic -)
        obj.ondisplay = func
        {
            if (!me.nd_initialised)
                me.nd_init();
        };
        #
        # most updates performed by the canvas nav display directly.
        obj.update = func
        {
        };        
        return obj;
    },
};
