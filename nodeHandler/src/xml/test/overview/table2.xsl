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
            <xsl:apply-templates select="/context/nodes/node[1]" mode="first"/>

          </tbody>
        </table>
      </body>
    </html>
  </xsl:template>
  <xsl:template match="node" mode="first">
    <xsl:param name="row" select="@x"/>
    <xsl:apply-templates select="." mode="row">
      <xsl:with-param name="row" select="$row"/>
    </xsl:apply-templates>
  </xsl:template>
  <xsl:template match="node" mode="row">
    <xsl:param name="row"/>
    <xsl:param name="next_row" select="$row + 1"/>
    <tr>
      <xsl:apply-templates select=".">
        <xsl:with-param name="row" select="$row"/>
      </xsl:apply-templates>
    </tr>

    <xsl:apply-templates select="../node[@x = $next_row][1]" mode="row">
      <xsl:with-param name="row" select="$next_row"/>
    </xsl:apply-templates>
  </xsl:template>
  <xsl:template match="node">
    <xsl:param name="row"/>
    <xsl:param name="x" select="@x"/>
    <!-- <xsl:param name="xPref" select="preceding-sibling::*[1]/@x"/> -->
    <xsl:if test="$x = $row">
      <td>
        <xsl:value-of select="$x"/>@<xsl:value-of select="@y"/>
      </td>
      <xsl:apply-templates select="following-sibling::*[1]">
        <xsl:with-param name="row" select="$row"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>
