function validate () {
	if ( (document.getElementById('host').value=="")
	   ||(document.getElementById('login').value=="")
	   ||(document.getElementById('password').value=="")
	){
    	alert('Поля не заполнены!');
		return false;
        };
};
