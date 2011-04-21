$(function() {
    $('select').change(function() {
        var name=$(this).attr('name');
        name=name.slice(0, name.indexOf('['));
        var res_win=$('#' + name + '_reservation_window');

        if($(this).val().match(/no/i) == null) {
            res_win.css('color', 'black');
            res_win.removeAttr('disabled');
        }
        else {
            res_win.css('color', 'white');
            res_win.attr('disabled', 'disabled');
        }
    });
});