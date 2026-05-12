const express = require('express');
const catalogRoutes = require('./catalogRoutes');
const streamRoutes = require('./streamRoutes');

const router = express.Router();

router.use('/', streamRoutes);
router.use('/', catalogRoutes);

module.exports = router;
