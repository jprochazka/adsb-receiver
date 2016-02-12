$(document).ready(function () {
    $('input:radio[name=dateFormatSlelection]').change(function () {
        $('#dateFormat').val($(this).val());
    });
    $('#dateFormat').keyup(function () {
        switch ($(this).val()) {
            case 'F jS, Y':
                $('input:radio[name=dateFormatSlelection]')[0].checked = true;
                break;
            case 'Y-m-d':
                $('input:radio[name=dateFormatSlelection]')[1].checked = true;
                break;
            case 'm/d/Y':
                $('input:radio[name=dateFormatSlelection]')[2].checked = true;
                break;
            case 'd/m/Y':
                $('input:radio[name=dateFormatSlelection]')[3].checked = true;
                break;
            default:
                $('input:radio[name=dateFormatSlelection]').attr('checked', false);
        }
    });
});