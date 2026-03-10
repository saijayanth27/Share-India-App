const express = require('express');
const mysql = require('mysql2/promise'); // MariaDB is compatible with mysql2
const app = express();
app.use(express.json());

const pool = mysql.createPool({
    host: '82.25.121.78',
    port: 3306,
    user: 'u646714351_TETRA_TEST',
    password: '!Tetra123$',
    database: 'u646714351_TETRA_TEST',
    waitForConnections: true,
    connectionLimit: 10
});

app.post("/add-questionnaire", async (req, res) => {
    try {
        const { Regno, INTDT, CONTACTNO, INTNAME, HT, WT } = req.body;
        const sql = `INSERT INTO QUESTIONNAIRE (Regno, INTDT, CONTACTNO, INTNAME, HT, WT) VALUES (?, ?, ?, ?, ?, ?)`;
        await pool.execute(sql, [Regno, INTDT, CONTACTNO, INTNAME, HT, WT]);
        res.json({ message: "Inserted successfully" });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Insert failed" });
    }
});

// app.get("/get-questionnaires", async (req, res) => {
//     try {
//         const [rows] = await pool.execute("SELECT * FROM QUESTIONNAIRE ORDER BY id DESC LIMIT 100");
//         res.json(rows);
//     } catch (error) {
//         console.error(error);
//         res.status(500).json({ error: "Fetch failed" });
//     }
// });

app.listen(3000, '0.0.0.0', () => {
    console.log('✅ API Server is running on http://0.0.0.0:3000');
});