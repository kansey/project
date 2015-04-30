function validate () {
	if ((document.getElementById('log').value=="") || (document.getElementById('pas').value=="")){
		alert('Поля не заполнены!');
		return false;
    };
};