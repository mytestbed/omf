<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xsl:output version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="no" media-type="text/html"/>
  <xsl:template match="/">
    <html>
      <head>
        <title>Grid Status</title>
      </head>
      <body>
        <table border="1">
          <tbody>
            <tr>
              <xsl:apply-templates select="/context/nodes/node"/>
            </tr>
          </tbody>
        </table>
      </body>
    </html>
  </xsl:template>
  <xsl:template match="node">
    <xsl:param name="x" select="@x"/>
    <xsl:param name="xPref" select="preceding-sibling::*[1]/@x"/>
    <xsl:if test="$x != $xPref">
      <xsl:text disable-output-escaping="yes"><![CDATA[</tr><tr>]]></xsl:text>
    </xsl:if>
      <td><xsl:value-of select="$x"/>@<xsl:value-of select="@y"/></td>
  </xsl:template>
</xsl:stylesheet>
