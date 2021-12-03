$(document).ready(function(){

    $("#path").css("border-color", colors.backgroundColor);
    $("h1").css("color", colors.backgroundColor);
    $("#options").css("border-color", colors.backgroundColor);
    $("#content a").css("color", colors.tableLinkColor);
    
        
    $("a.a-download").on("click", function(e){
        e.preventDefault();
        var link = $(this).attr('href');
        if (link.substring(0, 8) == "download") {
            window.location.href = link;
        }
        else {
            ajaxReload(link);
        }
        return false;
    });

        
    $("#sel-repo").change(function() {
        var repo = $("\#sel-repo option:checked").val(); 
        var link = "changeRepo/" + repo;
        ajaxReload(link);
    });
    
    $("input[type='checkbox']").change(function() {
        var visibility = 'hidden';
        var countChecked = 0;
        $("input[type='checkbox']").each(function() {
            if ($(this).is(":checked")) {
                visibility = "visible";
                countChecked++;
            }
        });
        $("#pDeleteChecked").css("visibility", visibility);
        if (countChecked == 1) {
            $("#pShareChecked").css("visibility", 'visible');
        }
        else {
            $("#pShareChecked").css("visibility", 'hidden');
        }
    });
    
    $("#dlgNewFolder").dialog({
        autoOpen: false,
        width: 400,
        modal: true,
        buttons: [
            {
                text: "Ok",
                click: function() {
                    $('html, body').css("cursor", "wait");
                    var newFolderName = $('#inpNewFolderName').val();
                    if (newFolderName.length >= 1){
                        $.post("createFolder", {"newFolder" : newFolderName}, function(){
                            location.reload();
                        });
                    }
                }
            },
            {
                text: "Cancel",
                click: function() {
                    $( this ).dialog( "close" );
                }
            }
        ]
    });
    
    $("#dlgConfirmDelete").dialog({
        autoOpen: false,
        width: 400,
        modal: true,
        buttons: [
            {
                text: "Ok",
                click: function() {
                    var files = [];
                    $("input:checkbox:checked").each(function() {
                        var string = $(this).parent().siblings().find(".a-download").attr("href");
                        var n = string.indexOf("/") + 1;
                        string = string.substr(n);  
                        files.push(string);
                    });
    
                    $('html, body').css("cursor", "wait");                        
                    $.post("delete", {"pointers" : files}, function(){
                        location.reload();
                    });
                }
            },
            {
                text: "Cancel",
                click: function() {
                    $( this ).dialog( "close" );
                }
            }
        ]
    });
    
    $("#dlgUpload").dialog({
        autoOpen: false,
        width: 400,
        modal: true,
        buttons: [
            {
                text: "Cancel",
                click: function() {
                    $( this ).dialog( "close" );
                }
            }
        ]
    });
    
    $("#dlgShare").dialog({
        autoOpen: false,
        width: 400,
        modal: true,
        buttons: [
            {
                text: "Cancel",
                click: function() {
                    $( this ).dialog( "close" );
                }
            }
        ],
        open: function() {
            var dlPath = $("input:checkbox:checked").parent().siblings(".tdLink").children("a").first().attr("href");
            var filepart = dlPath.substr(9);
            var serverpart = "https://" + window.location.host
            $("#dlgShare > input").val(serverpart + "/sharedFile/" + filepart);
            
        }
    });
});

function ajaxReload(link) {
    $('html, body').css("cursor", "wait");
    $.get(link).done(function(){
        location.reload();
    });
}

function deleteChecked() {
    event.preventDefault();
    $("#dlgConfirmDelete").dialog("open");
}

function createFolder() {
    event.preventDefault();
    $("#dlgNewFolder").dialog("open");
}

function uploadFile() {
    event.preventDefault();
    $("#dlgUpload").dialog("open");
}

function shareChecked() {
    event.preventDefault();
    $("#dlgShare").dialog("open");
}