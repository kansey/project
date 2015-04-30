function validate () {
    var form = document.getElementById('reg');
    var formElements = form.elements;
    if (document.getElementById('password').value != document.getElementById('confirm-pas').value){
        alert('Пароли не совпадают!');
        return false;
    };
    
    for (var j=0; j<formElements.length; j++) {
        if ((formElements[j].type=="text") || (formElements[j].type=="password")){
            if (!formElements[j].value) {
                alert('Поле не заполнены');
                return false;
            }; 
        };
    };
};

