<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema">
    <xsl:output version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="no" media-type="text/html" />
    <xsl:template match="/">
        <html>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
            <head />
            <body>
                <xsl:for-each select="context">
                    <xsl:for-each select="nodes">
                        <table border="1">
                            <thead>
                                <tr>
                                    <td>number</td>
                                    <td>node</td>
                                </tr>
                            </thead>
                            <tbody>
                                <xsl:for-each select="row">
                                    <tr>
                                        <td>
                                            <xsl:for-each select="@number">
                                                <xsl:value-of select="." />
                                            </xsl:for-each>
                                        </td>
                                        <td>
                                            <xsl:for-each select="node">
                                                <xsl:apply-templates />
                                            </xsl:for-each>
                                        </td>
                                    </tr>
                                </xsl:for-each>
                            </tbody>
                        </table>
                    </xsl:for-each>
                </xsl:for-each>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
