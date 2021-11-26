const express = require('express')
const app = express();

const port=9999;

app.get('/', (req, res) => {
    res.json({ message: 'hello' })
})

app.listen(port, () => console.log(`listnin\' on ${port}`))


