// so, scrolling stuff
// the idea is to write a function that can scroll the form to a specific element,
// usually a field, or a button, maybe a grop header
// It's probably good enough to have one scrolling function, and do the conversion in the function call
// i.e.: scrollToElement(getFormElement(fildName)) or directly like scrollToElement(elementName)

function scrollToFormElement(el) {
  // scrolling is done here
  // we measure the distance from the top of the container form_space and offset it with 40 pixels for the header
  //fill this at some point
}

function scrollToFormField(fieldName) {
  if (Utils.getNameFromPath(":", fieldName) == fieldName) {
    fieldName = $celaneseCustomJS.getXpath(fieldName);
  }
  let binding = Utils.formatBindingFromXpath(fieldName);
  //get the first element
  let elem = $j("[data-link = '" + binding + "'").first();
  //and now we scroll
  scrollToFormElement(elem);
}

//using it
scrollToFormField('fieldName');
//or
scrollToFormField('/my:fieldName');
//or, we can even do things like this
//so it goes to the first required field
scrollToFormElement($j(".required_field").first());