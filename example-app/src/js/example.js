import { Zip } from 'capacitor-plugin-zip';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    Zip.echo({ value: inputValue })
}
