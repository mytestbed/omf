def affiliations_xml
  <<-NODE
<iq type='result'
    from='pubsub.shakespeare.lit'
    to='francisco@denmark.lit'
    id='affil1'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <affiliations>
      <affiliation node='node1' affiliation='owner'/>
      <affiliation node='node2' affiliation='owner'/>
      <affiliation node='node3' affiliation='publisher'/>
      <affiliation node='node4' affiliation='outcast'/>
      <affiliation node='node5' affiliation='member'/>
      <affiliation node='node6' affiliation='none'/>
    </affiliations>
  </pubsub>
</iq>
  NODE
end

def subscriptions_xml
  <<-NODE
<iq type='result'
    from='pubsub.shakespeare.lit'
    to='francisco@denmark.lit'
    id='affil1'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <subscriptions>
      <subscription node='node1' jid='francisco@denmark.lit' subscription='subscribed' subid='fd8237yr872h3f289j2'/>
      <subscription node='node2' jid='francisco@denmark.lit' subscription='subscribed' subid='h8394hf8923ju'/>
      <subscription node='node3' jid='francisco@denmark.lit' subscription='unconfigured'/>
      <subscription node='node4' jid='francisco@denmark.lit' subscription='pending'/>
      <subscription node='node5' jid='francisco@denmark.lit' subscription='none'/>
    </subscriptions>
  </pubsub>
</iq>
  NODE
end

def event_notification_xml
  <<-NODE
<message from='pubsub.shakespeare.lit' to='francisco@denmark.lit' id='foo'>
  <event xmlns='http://jabber.org/protocol/pubsub#event'>
    <items node='princely_musings'>
      <item id='ae890ac52d0df67ed7cfdf51b644e901'/>
    </items>
  </event>
</message>
  NODE
end

def event_subids_xml
  <<-NODE
<message from='pubsub.shakespeare.lit' to='francisco@denmark.lit' id='foo'>
  <event xmlns='http://jabber.org/protocol/pubsub#event'>
    <items node='princely_musings'>
      <item id='ae890ac52d0df67ed7cfdf51b644e901'/>
    </items>
  </event>
  <headers xmlns='http://jabber.org/protocol/shim'>
    <header name='SubID'>123-abc</header>
    <header name='SubID'>004-yyy</header>
  </headers>
</message>
  NODE
end

def unsubscribe_xml
  <<-NODE
<iq type='error'
    from='pubsub.shakespeare.lit'
    to='francisco@denmark.lit/barracks'
    id='unsub1'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
     <unsubscribe node='princely_musings' jid='francisco@denmark.lit'/>
  </pubsub>
  <error type='modify'>
    <bad-request xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
    <subid-required xmlns='http://jabber.org/protocol/pubsub#errors'/>
  </error>
</iq>
  NODE
end

def subscription_xml
  <<-NODE
<iq type='result'
    from='pubsub.shakespeare.lit'
    to='francisco@denmark.lit/barracks'
    id='sub1'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <subscription
        node='princely_musings'
        jid='francisco@denmark.lit'
        subid='ba49252aaa4f5d320c24d3766f0bdcade78c78d3'
        subscription='subscribed'/>
  </pubsub>
</iq>
  NODE
end

def subscribe_xml
  <<-NODE
<iq type='set'
    from='francisco@denmark.lit/barracks'
    to='pubsub.shakespeare.lit'
    id='sub1'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <subscribe
        node='princely_musings'
        jid='francisco@denmark.lit'/>
  </pubsub>
</iq>
  NODE
end

def publish_xml
  <<-NODE
<iq type='result'
    from='pubsub.shakespeare.lit'
    to='hamlet@denmark.lit/blogbot'
    id='publish1'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <publish node='princely_musings'>
      <item id='ae890ac52d0df67ed7cfdf51b644e901'/>
    </publish>
  </pubsub>
</iq>
  NODE
end

def created_xml
  <<-NODE
<iq type='result'
    from='pubsub.shakespeare.lit'
    to='hamlet@denmark.lit/elsinore'
    id='create2'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <create node='25e3d37dabbab9541f7523321421edc5bfeb2dae'/>
  </pubsub>
</iq>
  NODE
end

def published_xml
  <<-NODE
<iq type='result'
    from='pubsub.shakespeare.lit'
    to='hamlet@denmark.lit/blogbot'
    id='publish1'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <publish node='princely_musings'>
      <item id='ae890ac52d0df67ed7cfdf51b644e901'/>
    </publish>
  </pubsub>
</iq>
  NODE
end

def fabulous_xmpp_empty_success_xml
  <<-NODE
<iq type='result'
    from='pubsub.shakespeare.lit'
    id='bob'/>
  NODE
end

# OMF messages
def omf_created_xml
  <<-NODE
<message from="pubsub.localhost" to="bravo@localhost" id="mclaren__bravo@localhost__FT6ea">
  <event xmlns="http://jabber.org/protocol/pubsub#event">
    <items node="mclaren">
      <item id="4JMgcKzxFDLsP74">
        <inform xmlns="http://schema.mytestbed.net/omf/6.0/protocol" msg_id="a2b6aba9f11dc5bb88306a32d0720641f5020c1f">
          <context_id>bf840fe9-c176-4fae-b7de-6fc27f183f76</context_id>
          <inform_type>CREATION_OK</inform_type>
          <resource_id>444f17fb-546e-4685-a0d0-63e64fa046c8</resource_id>
          <resource_address>444f17fb-546e-4685-a0d0-63e64fa046c8</resource_address>
        </inform>
      </item>
    </items>
  </event>
  <headers xmlns="http://jabber.org/protocol/shim">
    <header name="pubsub#subid">Mui0v6cdP9dj4Fo1wVj8KwD48WA606Q7oXWin5P1</header>
  </headers>
</message>
  NODE
end

def omf_status_xml
  <<-NODE
<message from="pubsub.localhost" to="bravo@localhost" id="mclaren__bravo@localhost__FT6ea">
  <event xmlns="http://jabber.org/protocol/pubsub#event">
    <items node="mclaren">
      <item id="4JMgcKzxFDLsP74">
        <inform xmlns="http://schema.mytestbed.net/omf/6.0/protocol" msg_id="a2b6aba9f11dc5bb88306a32d0720641f5020c1f">
          <context_id>bf840fe9-c176-4fae-b7de-6fc27f183f76</context_id>
          <inform_type>STATUS</inform_type>
          <property key="bob">bob</property>
        </inform>
      </item>
    </items>
  </event>
  <headers xmlns="http://jabber.org/protocol/shim">
    <header name="pubsub#subid">Mui0v6cdP9dj4Fo1wVj8KwD48WA606Q7oXWin5P1</header>
  </headers>
</message>
  NODE
end

def omf_failed_xml
  <<-NODE
<message from="pubsub.localhost" to="bravo@localhost" id="mclaren__bravo@localhost__FT6ea">
  <event xmlns="http://jabber.org/protocol/pubsub#event">
    <items node="mclaren">
      <item id="4JMgcKzxFDLsP74">
        <inform xmlns="http://schema.mytestbed.net/omf/6.0/protocol" msg_id="a2b6aba9f11dc5bb88306a32d0720641f5020c1f">
          <context_id>bf840fe9-c176-4fae-b7de-6fc27f183f76</context_id>
          <inform_type>CREATION_FAILED</inform_type>
          <reason>No idea</reason>
        </inform>
      </item>
    </items>
  </event>
  <headers xmlns="http://jabber.org/protocol/shim">
    <header name="pubsub#subid">Mui0v6cdP9dj4Fo1wVj8KwD48WA606Q7oXWin5P1</header>
  </headers>
</message>
  NODE
end

def omf_released_xml
  <<-NODE
<message from="pubsub.localhost" to="bravo@localhost" id="mclaren__bravo@localhost__FT6ea">
  <event xmlns="http://jabber.org/protocol/pubsub#event">
    <items node="mclaren">
      <item id="4JMgcKzxFDLsP74">
        <inform xmlns="http://schema.mytestbed.net/omf/6.0/protocol" msg_id="a2b6aba9f11dc5bb88306a32d0720641f5020c1f">
          <context_id>bf840fe9-c176-4fae-b7de-6fc27f183f76</context_id>
          <inform_type>RELEASED</inform_type>
          <resource_id>444f17fb-546e-4685-a0d0-63e64fa046c8</resource_id>
        </inform>
      </item>
    </items>
  </event>
  <headers xmlns="http://jabber.org/protocol/shim">
    <header name="pubsub#subid">Mui0v6cdP9dj4Fo1wVj8KwD48WA606Q7oXWin5P1</header>
  </headers>
</message>
  NODE
end
