const express = require('express');
const catalogRoutes = require('./catalogRoutes');
const embedRoutes = require('./embedRoutes');

const router = express.Router();

router.use('/', embedRoutes);
router.use('/', catalogRoutes);

module.exports = router;
