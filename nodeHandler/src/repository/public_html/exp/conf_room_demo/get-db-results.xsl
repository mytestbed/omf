<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xlink="http://www.w3.org/1999/xlink">
  <xsl:output version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="no" media-type="text/html"/>
  <xsl:template match="/">
    <html>
      <head><title>Results Status</title>
      </head>
      <body>
        <h2 align="center"> Experiment Results </h2>
        <xsl:apply-templates select="/context/oml/database-name" />
      </body>
    </html>
  </xsl:template>

  <xsl:template match="database-name">
    <xsl:param name="dbName" select="text()"/>
    <xsl:param name="dbLoc" select="concat('handler-otg.cgi?node5-4=on&amp;throughput=on&amp;size=500&amp;refresh=3&amp;db=', $dbName)"/>
    <a><xsl:attribute name="href"><xsl:value-of select="$dbLoc"/></xsl:attribute>Plot Cumulative Aggregate Throughput at Receiver (node5-4)</a>
  </xsl:template>
</xsl:stylesheet>
