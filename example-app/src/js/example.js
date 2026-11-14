import { unzip } from 'capacitor-plugin-zip';

window.testUnzip = async () => {
  const source = document.getElementById('source').value;
  const destination = document.getElementById('destination').value;
  const output = document.getElementById('output');
  output.textContent = 'Extracting...';
  try {
    const { entries } = await unzip({ source, destination }, ({ loaded, total }) => {
      output.textContent = `${loaded} of ${total}`;
    });
    output.textContent = `Done: ${entries} entries`;
  } catch (error) {
    output.textContent = `Failed (${error.code}): ${error.message}`;
  }
};
